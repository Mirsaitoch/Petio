# Post Image Upload — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users attach one photo (gallery or camera) when creating a post; the photo is uploaded via multipart/form-data together with the post data.

**Architecture:** `NewPostSheet` holds the selected `UIImage?` in local state; on publish it calls `AppState.addPost(post, image:)`; if an image is present `HTTPAPIClient.addPostWithImage` sends a single `multipart/form-data` POST to `/posts`; otherwise the existing JSON path is used unchanged.

**Tech Stack:** SwiftUI, PhotosUI, UIKit (UIImagePickerController already in codebase), URLSession multipart, Swift Testing framework.

---

### Task 1: Add `PostImagePickerButton` to `ImagePickerView.swift`

New component that lets the user pick one photo and holds the result as `UIImage?` in memory (no local file save — unlike `AvatarPickerButton`).

**Files:**
- Modify: `Petio-ios/Petio/Design/ImagePickerView.swift`

**Step 1: Add the new struct after the existing `AvatarPickerButton`**

Open `Petio-ios/Petio/Design/ImagePickerView.swift` and append the following after line 87 (after `saveImageLocally`), before `// MARK: - CameraPickerView`:

```swift
// MARK: - PostImagePickerButton

struct PostImagePickerButton: View {
    @Binding var selectedImage: UIImage?

    @State private var showOptions = false
    @State private var showGallery = false
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        Button { showOptions = true } label: {
            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            selectedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5).clipShape(Circle()))
                        }
                        .padding(4)
                    }
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(PetCareTheme.border, lineWidth: 1.5)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28))
                            .foregroundColor(PetCareTheme.muted)
                    )
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog("Фото", isPresented: $showOptions, titleVisibility: .visible) {
            Button("Выбрать из галереи") { showGallery = true }
            Button("Сделать фото") { showCamera = true }
            if selectedImage != nil {
                Button("Убрать фото", role: .destructive) { selectedImage = nil }
            }
            Button("Отмена", role: .cancel) { }
        }
        .photosPicker(isPresented: $showGallery, selection: $selectedItem, matching: .images)
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                selectedImage = image
                showCamera = false
            } onCancel: {
                showCamera = false
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }
}
```

**Step 2: Build the project to verify it compiles**

In Xcode: `⌘ + B` (or `Product → Build`).
Expected: Build Succeeded, no errors.

**Step 3: Commit**

```bash
git add Petio-ios/Petio/Design/ImagePickerView.swift
git commit -m "feat: add PostImagePickerButton for in-memory image selection"
```

---

### Task 2: Add `addPostWithImage` to `APIClientProtocol` and `MockAPIClient`

**Files:**
- Modify: `Petio-ios/Petio/Core/Network/APIClient.swift:37-40`
- Modify: `Petio-ios/Petio/Core/Network/Mock/MockAPIClient.swift`

**Step 1: Add the method to the protocol**

In `APIClient.swift`, add after line 38 (`func addPost(_ post: Post) async throws -> Post`):

```swift
func addPostWithImage(_ post: Post, imageData: Data) async throws -> Post
```

**Step 2: Add mock implementation**

In `MockAPIClient.swift`, add after the existing `func addPost`:

```swift
func addPostWithImage(_ post: Post, imageData: Data) async throws -> Post { post }
```

**Step 3: Build to verify**

`⌘ + B`
Expected: Build Succeeded.

**Step 4: Write a unit test for multipart data structure**

In `PetioTests/PetioTests.swift`, add:

```swift
@Test func multipartDataContainsImageAndContent() {
    let image = UIImage(systemName: "star")!
    let imageData = image.jpegData(compressionQuality: 0.8)!
    let boundary = "TestBoundary"
    let content = "Тестовый пост"
    let club = "Собаки"

    var body = Data()
    func append(_ string: String) { body.append(Data(string.utf8)) }
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n")
    append("Content-Type: image/jpeg\r\n\r\n")
    body.append(imageData)
    append("\r\n")
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"content\"\r\n\r\n")
    append(content)
    append("\r\n")
    append("--\(boundary)--\r\n")

    let bodyString = String(data: body, encoding: .utf8) ?? ""
    #expect(bodyString.contains("name=\"image\""))
    #expect(bodyString.contains("name=\"content\""))
    #expect(bodyString.contains(content))
    #expect(body.count > imageData.count)
}
```

**Step 5: Run the test**

In Xcode: `⌘ + U` or run the specific test.
Expected: PASS.

**Step 6: Commit**

```bash
git add Petio-ios/Petio/Core/Network/APIClient.swift \
        Petio-ios/Petio/Core/Network/Mock/MockAPIClient.swift \
        Petio-ios/PetioTests/PetioTests.swift
git commit -m "feat: add addPostWithImage to protocol, mock, and multipart test"
```

---

### Task 3: Implement multipart upload in `HTTPAPIClient`

**Files:**
- Modify: `Petio-ios/Petio/Core/Network/HTTPAPIClient.swift`

**Step 1: Add the `buildMultipartBody` helper and `addPostWithImage` method**

In `HTTPAPIClient.swift`, in the `// MARK: - Posts` section, add after the existing `addPost` method (after line 170):

```swift
func addPostWithImage(_ post: Post, imageData: Data) async throws -> Post {
    let boundary = UUID().uuidString
    guard var components = URLComponents(string: baseURL + "/posts"),
          let url = components.url else { throw APIError.invalidURL }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    if let token = authManager.getToken() {
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    req.httpBody = buildMultipartBody(post: post, imageData: imageData, boundary: boundary)
    return try await perform(req)
}

private func buildMultipartBody(post: Post, imageData: Data, boundary: String) -> Data {
    var body = Data()
    func append(_ string: String) { body.append(Data(string.utf8)) }

    // Image part
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n")
    append("Content-Type: image/jpeg\r\n\r\n")
    body.append(imageData)
    append("\r\n")

    // Text fields
    let fields: [(String, String)] = [
        ("id", post.id),
        ("author", post.author),
        ("content", post.content),
        ("club", post.club),
        ("timestamp", post.timestamp),
    ]
    for (name, value) in fields {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append(value)
        append("\r\n")
    }

    append("--\(boundary)--\r\n")
    return body
}
```

**Step 2: Build**

`⌘ + B`
Expected: Build Succeeded.

**Step 3: Commit**

```bash
git add Petio-ios/Petio/Core/Network/HTTPAPIClient.swift
git commit -m "feat: implement multipart post upload in HTTPAPIClient"
```

---

### Task 4: Update `AppState.addPost` to accept optional image

**Files:**
- Modify: `Petio-ios/Petio/Services/AppState.swift:269-276`

**Step 1: Replace the existing `addPost` method**

Find (lines 269–276):

```swift
func addPost(_ post: Post) async {
    do {
        let added = try await api.addPost(post)
        posts.insert(added, at: 0)
    } catch {
        posts.insert(post, at: 0)
    }
}
```

Replace with:

```swift
func addPost(_ post: Post, image: UIImage? = nil) async {
    do {
        let added: Post
        if let image, let imageData = image.jpegData(compressionQuality: 0.8) {
            added = try await api.addPostWithImage(post, imageData: imageData)
        } else {
            added = try await api.addPost(post)
        }
        posts.insert(added, at: 0)
    } catch {
        posts.insert(post, at: 0)
    }
}
```

**Step 2: Add `import UIKit` at the top if not already present**

`AppState.swift` already imports `SwiftUI` which transitively includes UIKit, so UIImage is available. No change needed.

**Step 3: Build**

`⌘ + B`
Expected: Build Succeeded.

**Step 4: Commit**

```bash
git add Petio-ios/Petio/Services/AppState.swift
git commit -m "feat: update AppState.addPost to support optional UIImage"
```

---

### Task 5: Update `NewPostSheet` — add image picker and change callback

**Files:**
- Modify: `Petio-ios/Petio/Features/Feed/NewPostSheet.swift`

**Step 1: Replace the entire file content**

```swift
//
//  NewPostSheet.swift
//  Petio
//
//  Шит создания нового поста: выбор клуба, текст, фото.
//

import SwiftUI

struct NewPostSheet: View {
    let user: UserProfile
    let onSave: (Post, UIImage?) -> Void
    let onCancel: () -> Void

    @State private var content = ""
    @State private var club = "Собаки"
    @State private var selectedImage: UIImage?
    private let clubs = ["Собаки", "Кошки", "Птицы", "Кролики", "Экзотика"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Клуб") {
                    Picker("Клуб", selection: $club) {
                        ForEach(clubs, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Section("Текст") {
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                }
                Section("Фото (необязательно)") {
                    PostImagePickerButton(selectedImage: $selectedImage)
                }
            }
            .navigationTitle("Новый пост")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Опубликовать") {
                        let post = Post(
                            id: UUID().uuidString,
                            author: user.username,
                            avatar: user.avatar,
                            content: content,
                            image: nil,
                            likes: 0,
                            comments: [],
                            club: club,
                            timestamp: "Только что",
                            liked: false
                        )
                        onSave(post, selectedImage)
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
```

**Step 2: Build**

`⌘ + B`
Expected: Build error in `FeedView.swift` — the closure signature doesn't match yet. This is expected.

---

### Task 6: Update `FeedView` to pass image to `addPost`

**Files:**
- Modify: `Petio-ios/Petio/Features/Feed/FeedView.swift:46-49`

**Step 1: Update the `NewPostSheet` call**

Find (lines 46–49):

```swift
NewPostSheet(user: app.user) { post in
    Task { await app.addPost(post) }
    showNewPost = false
} onCancel: { showNewPost = false }
```

Replace with:

```swift
NewPostSheet(user: app.user) { post, image in
    Task { await app.addPost(post, image: image) }
    showNewPost = false
} onCancel: { showNewPost = false }
```

**Step 2: Build**

`⌘ + B`
Expected: Build Succeeded.

**Step 3: Run tests**

`⌘ + U`
Expected: All tests PASS.

**Step 4: Commit**

```bash
git add Petio-ios/Petio/Features/Feed/NewPostSheet.swift \
        Petio-ios/Petio/Features/Feed/FeedView.swift
git commit -m "feat: wire post image picker into create post flow"
```

---

## Manual Testing Checklist

After all tasks are complete, test on simulator or device:

1. Open the app → go to Feed tab
2. Tap "+" to open new post sheet
3. Verify "Фото (необязательно)" section appears with a placeholder button
4. Tap the placeholder → verify confirmation dialog with "Выбрать из галереи" / "Сделать фото"
5. Pick a photo from gallery → verify 80×80 preview with ✕ button appears
6. Tap ✕ → verify photo is removed and placeholder returns
7. Write some text, tap "Опубликовать" → verify the post appears in the feed
8. Post without a photo → verify it still works (JSON path unchanged)
9. Open a post with image → verify image renders in PostCard via AsyncImage

---

## Summary of Changed Files

| File | Change |
|------|--------|
| `Design/ImagePickerView.swift` | +`PostImagePickerButton` struct |
| `Core/Network/APIClient.swift` | +`addPostWithImage` in protocol |
| `Core/Network/Mock/MockAPIClient.swift` | +`addPostWithImage` mock |
| `Core/Network/HTTPAPIClient.swift` | +`addPostWithImage` + `buildMultipartBody` |
| `Services/AppState.swift` | Update `addPost(_:image:)` |
| `Features/Feed/NewPostSheet.swift` | Add image picker, change `onSave` signature |
| `Features/Feed/FeedView.swift` | Pass `image` to `addPost` |
| `PetioTests/PetioTests.swift` | Add multipart structure test |
