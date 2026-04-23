# API Migration & Pagination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate iOS app to new API host with cursor-based pagination and infinite scroll for posts feed.

**Architecture:** Model-first approach (PostsResponse) → Protocol update → Client implementation → ViewModel for pagination logic → View integration with infinite scroll and pull-to-refresh.

**Tech Stack:** SwiftUI, async/await, URLSession, cursor-based pagination (ID-based).

---

## File Structure

```
Petio-ios/Petio/
├── Core/
│   ├── Network/
│   │   ├── Endpoints.swift (MODIFY)
│   │   ├── APIClient.swift (MODIFY)
│   │   └── HTTPAPIClient.swift (MODIFY)
│   └── Domain/
│       └── Models.swift (MODIFY)
├── Features/Feed/
│   ├── FeedView.swift (MODIFY)
│   ├── FeedViewModel.swift (CREATE)
│   └── PostCard.swift (no changes)
└── AppContainer.swift (MODIFY)

Petio-ios/PetioTests/
└── Features/Feed/
    └── FeedViewModelTests.swift (CREATE)
```

---

## Task 1: Update baseURL to new host

**Files:**
- Modify: `Petio-ios/Petio/Core/Network/Endpoints.swift:10`
- Modify: `Petio-ios/Petio/Core/Network/HTTPAPIClient.swift:17`

- [ ] **Step 1: Update Endpoints.baseURL**

Open `Endpoints.swift` and change line 10:

```swift
enum Endpoints {
    static var baseURL: URL? { URL(string: "http://158.160.235.224/v1") }
    // ... rest remains the same
}
```

- [ ] **Step 2: Update HTTPAPIClient default init parameter**

Open `HTTPAPIClient.swift` and update line 17:

```swift
init(authManager: AuthManager, baseURL: String = "http://158.160.235.224/v1") {
    self.authManager = authManager
    self.baseURL = baseURL
}
```

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/Petio/Core/Network/Endpoints.swift Petio-ios/Petio/Core/Network/HTTPAPIClient.swift
git commit -m "chore: update API host to 158.160.235.224"
```

---

## Task 2: Add PostsResponse model

**Files:**
- Modify: `Petio-ios/Petio/Core/Domain/Models.swift` (add after Post struct)

- [ ] **Step 1: Add PostsResponse struct**

Find the Post struct in Models.swift (around line 135). After the Post struct definition, add:

```swift
// MARK: - Feed Pagination

struct PostsResponse: Decodable {
    let posts: [Post]
    let hasMore: Bool    // есть ли еще старых постов (при скролле вниз)
    let hasNew: Bool     // есть ли новые посты сверху (при pull-to-refresh)

    enum CodingKeys: String, CodingKey {
        case posts
        case hasMore = "has_more"
        case hasNew = "has_new"
    }
}
```

- [ ] **Step 2: Verify by building**

```bash
cd Petio-ios && xcodebuild -scheme Petio -configuration Debug -derivedDataPath build 2>&1 | head -20
```

Expected: No errors related to PostsResponse.

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/Petio/Core/Domain/Models.swift
git commit -m "feat: add PostsResponse model for paginated posts"
```

---

## Task 3: Update APIClientProtocol fetchPosts signature

**Files:**
- Modify: `Petio-ios/Petio/Core/Network/APIClient.swift:37`

- [ ] **Step 1: Update fetchPosts protocol definition**

Open `APIClient.swift` and replace line 37:

```swift
func fetchPosts(
    club: String?,
    limit: Int = 20,
    afterID: String? = nil,
    beforeID: String? = nil
) async throws -> PostsResponse
```

Replace the old `func fetchPosts(club: String?) async throws -> [Post]` line.

- [ ] **Step 2: Verify no compilation errors**

```bash
cd Petio-ios && xcodebuild -scheme Petio -configuration Debug -derivedDataPath build 2>&1 | grep -E "error:|warning:" | head -10
```

Expected: Some errors about HTTPAPIClient not implementing new signature (will fix in Task 4).

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/Petio/Core/Network/APIClient.swift
git commit -m "refactor: update fetchPosts signature for pagination support"
```

---

## Task 4: Implement fetchPosts in HTTPAPIClient

**Files:**
- Modify: `Petio-ios/Petio/Core/Network/HTTPAPIClient.swift` (find existing fetchPosts method ~line 218)

- [ ] **Step 1: Replace fetchPosts implementation**

Find the current `func fetchPosts(club: String?)` method in HTTPAPIClient (around line 218). Replace entire function with:

```swift
func fetchPosts(
    club: String?,
    limit: Int = 20,
    afterID: String? = nil,
    beforeID: String? = nil
) async throws -> PostsResponse {
    var qi: [URLQueryItem] = []
    if limit != 0 { qi.append(URLQueryItem(name: "limit", value: String(limit))) }
    if let afterID = afterID { qi.append(URLQueryItem(name: "after_id", value: afterID)) }
    if let beforeID = beforeID { qi.append(URLQueryItem(name: "before_id", value: beforeID)) }
    if let club = club, club != "Все" { qi.append(URLQueryItem(name: "club", value: club)) }

    print("[POSTS] fetchPosts запрос: club='\(club ?? "nil")', limit=\(limit), afterID=\(afterID ?? "nil"), beforeID=\(beforeID ?? "nil")")

    do {
        let response: PostsResponse = try await perform(try makeRequest(path: "/posts", queryItems: qi))
        print("[POSTS] fetchPosts успех: получено \(response.posts.count) постов, hasMore=\(response.hasMore), hasNew=\(response.hasNew)")
        return response
    } catch {
        print("[POSTS] fetchPosts ошибка: \(error)")
        throw error
    }
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd Petio-ios && xcodebuild -scheme Petio -configuration Debug -derivedDataPath build 2>&1 | grep -E "error:" | head -5
```

Expected: No errors (or only FeedView related, will fix later).

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/Petio/Core/Network/HTTPAPIClient.swift
git commit -m "feat: implement paginated fetchPosts with cursor-based pagination"
```

---

## Task 5: Create FeedViewModel with tests

**Files:**
- Create: `Petio-ios/Petio/Features/Feed/FeedViewModel.swift`
- Create: `Petio-ios/PetioTests/Features/Feed/FeedViewModelTests.swift`

- [ ] **Step 1: Create test file first (TDD)**

Create `Petio-ios/PetioTests/Features/Feed/FeedViewModelTests.swift`:

```swift
import XCTest
@testable import Petio

final class FeedViewModelTests: XCTestCase {

    var viewModel: FeedViewModel!
    var mockApiClient: MockAPIClient!

    override func setUp() {
        super.setUp()
        mockApiClient = MockAPIClient()
        viewModel = FeedViewModel(apiClient: mockApiClient)
    }

    override func tearDown() {
        viewModel = nil
        mockApiClient = nil
        super.tearDown()
    }

    @MainActor
    func testLoadInitial_FetchesPostsAndSetsHasMore() async throws {
        // Arrange
        let mockPosts = [
            Post(id: "1", author: "User1", avatar: nil, content: "Post 1", image: nil, likes: 0, comments: [], club: "Собаки", timestamp: "2026-04-23T10:00:00Z", liked: false),
            Post(id: "2", author: "User2", avatar: nil, content: "Post 2", image: nil, likes: 1, comments: [], club: "Собаки", timestamp: "2026-04-23T09:00:00Z", liked: false),
        ]
        let mockResponse = PostsResponse(posts: mockPosts, hasMore: true, hasNew: false)
        mockApiClient.postsResponseToReturn = mockResponse

        // Act
        await viewModel.loadInitial()

        // Assert
        XCTAssertEqual(viewModel.posts.count, 2)
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(viewModel.posts.first?.id, "1")
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testLoadMore_AppendsPostsWithAfterId() async throws {
        // Arrange
        let initialPosts = [
            Post(id: "1", author: "User1", avatar: nil, content: "Post 1", image: nil, likes: 0, comments: [], club: "Собаки", timestamp: "2026-04-23T10:00:00Z", liked: false),
        ]
        let initialResponse = PostsResponse(posts: initialPosts, hasMore: true, hasNew: false)

        let morePosts = [
            Post(id: "2", author: "User2", avatar: nil, content: "Post 2", image: nil, likes: 1, comments: [], club: "Собаки", timestamp: "2026-04-23T09:00:00Z", liked: false),
            Post(id: "3", author: "User3", avatar: nil, content: "Post 3", image: nil, likes: 2, comments: [], club: "Кошки", timestamp: "2026-04-23T08:00:00Z", liked: false),
        ]
        let moreResponse = PostsResponse(posts: morePosts, hasMore: false, hasNew: false)

        mockApiClient.postsResponseToReturn = initialResponse
        await viewModel.loadInitial()

        mockApiClient.postsResponseToReturn = moreResponse
        mockApiClient.lastAfterId = nil // Reset to capture new call

        // Act
        await viewModel.loadMore()

        // Assert
        XCTAssertEqual(viewModel.posts.count, 3) // 1 initial + 2 more
        XCTAssertEqual(viewModel.posts[1].id, "2")
        XCTAssertEqual(viewModel.posts[2].id, "3")
        XCTAssertFalse(viewModel.hasMore)
        XCTAssertEqual(mockApiClient.lastAfterId, "1") // Should be ID of last post from initial load
    }

    @MainActor
    func testRefresh_LoadsNewPostsWithBeforeId() async throws {
        // Arrange
        let initialPosts = [
            Post(id: "2", author: "User2", avatar: nil, content: "Post 2", image: nil, likes: 1, comments: [], club: "Собаки", timestamp: "2026-04-23T09:00:00Z", liked: false),
        ]
        let initialResponse = PostsResponse(posts: initialPosts, hasMore: false, hasNew: false)

        let newPosts = [
            Post(id: "3", author: "User3", avatar: nil, content: "Post 3", image: nil, likes: 2, comments: [], club: "Кошки", timestamp: "2026-04-23T10:30:00Z", liked: false),
            Post(id: "1", author: "User1", avatar: nil, content: "Post 1", image: nil, likes: 0, comments: [], club: "Собаки", timestamp: "2026-04-23T10:00:00Z", liked: false),
        ]
        let refreshResponse = PostsResponse(posts: newPosts, hasMore: true, hasNew: false)

        mockApiClient.postsResponseToReturn = initialResponse
        await viewModel.loadInitial()

        mockApiClient.postsResponseToReturn = refreshResponse
        mockApiClient.lastBeforeId = nil // Reset to capture new call

        // Act
        await viewModel.refresh()

        // Assert
        XCTAssertEqual(viewModel.posts.count, 4) // 1 initial + 2 new (prepended) + 1 old
        XCTAssertEqual(viewModel.posts[0].id, "3") // Newest should be first
        XCTAssertEqual(mockApiClient.lastBeforeId, "2") // Should be ID of first post before refresh
    }

    @MainActor
    func testSelectClub_ResetsStateAndLoadsInitial() async throws {
        // Arrange
        let dogPosts = [
            Post(id: "1", author: "User1", avatar: nil, content: "Dog 1", image: nil, likes: 0, comments: [], club: "Собаки", timestamp: "2026-04-23T10:00:00Z", liked: false),
        ]
        let dogResponse = PostsResponse(posts: dogPosts, hasMore: true, hasNew: false)

        let catPosts = [
            Post(id: "10", author: "User10", avatar: nil, content: "Cat 1", image: nil, likes: 5, comments: [], club: "Кошки", timestamp: "2026-04-23T09:00:00Z", liked: false),
        ]
        let catResponse = PostsResponse(posts: catPosts, hasMore: false, hasNew: false)

        mockApiClient.postsResponseToReturn = dogResponse
        await viewModel.loadInitial()

        mockApiClient.postsResponseToReturn = catResponse

        // Act
        await viewModel.selectClub("Кошки")

        // Assert
        XCTAssertEqual(viewModel.selectedClub, "Кошки")
        XCTAssertEqual(viewModel.posts.count, 1)
        XCTAssertEqual(viewModel.posts[0].id, "10")
        XCTAssertFalse(viewModel.hasMore)
    }

    @MainActor
    func testLoadInitial_HandlesError() async throws {
        // Arrange
        mockApiClient.errorToThrow = APIError.server(500)

        // Act & Assert
        await viewModel.loadInitial()

        XCTAssertTrue(viewModel.posts.isEmpty)
        XCTAssertNotNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
    }
}

// MARK: - Mock API Client

class MockAPIClient: APIClientProtocol {
    var postsResponseToReturn = PostsResponse(posts: [], hasMore: false, hasNew: false)
    var errorToThrow: APIError?

    var lastAfterId: String?
    var lastBeforeId: String?

    func fetchPets() async throws -> [Pet] { [] }
    func fetchPet(id: String) async throws -> Pet? { nil }
    func addPet(_ pet: Pet) async throws -> Pet { pet }
    func updatePet(_ pet: Pet) async throws -> Pet { pet }
    func deletePet(id: String) async throws { }

    func fetchReminders(petId: String?) async throws -> [Reminder] { [] }
    func addReminder(_ reminder: Reminder) async throws -> Reminder { reminder }
    func updateReminder(_ reminder: Reminder) async throws -> Reminder { reminder }
    func deleteReminder(id: String) async throws { }

    func fetchWeightHistory(petId: String) async throws -> [WeightRecord] { [] }
    func addWeightRecord(petId: String, _ record: WeightRecord) async throws { }

    func fetchDiary(petId: String) async throws -> [HealthDiaryEntry] { [] }
    func addDiaryEntry(_ entry: HealthDiaryEntry) async throws -> HealthDiaryEntry { entry }
    func updateDiaryEntry(_ entry: HealthDiaryEntry) async throws { }
    func deleteDiaryEntry(id: String) async throws { }

    func fetchArticles() async throws -> [Article] { [] }

    func fetchPosts(
        club: String?,
        limit: Int = 20,
        afterID: String? = nil,
        beforeID: String? = nil
    ) async throws -> PostsResponse {
        lastAfterId = afterID
        lastBeforeId = beforeID
        if let error = errorToThrow {
            throw error
        }
        return postsResponseToReturn
    }

    func addPost(_ post: Post) async throws -> Post { post }
    func addPostWithImage(_ post: Post, imageData: Data) async throws -> Post { post }
    func likePost(id: String, liked: Bool) async throws { }
    func addComment(postId: String, _ comment: Comment) async throws { }

    func sendChatMessage(_ text: String) async throws -> String { "" }

    func fetchProfile() async throws -> UserProfile {
        UserProfile(username: "test", email: nil, avatar: nil, bio: "", petsCount: 0, postsCount: 0, joinDate: "")
    }
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile { profile }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Petio-ios && xcodebuild test -scheme Petio -derivedDataPath build -only-testing Petio/FeedViewModelTests 2>&1 | tail -20
```

Expected: FAIL - "FeedViewModel" not found (type does not exist yet).

- [ ] **Step 3: Create FeedViewModel implementation**

Create `Petio-ios/Petio/Features/Feed/FeedViewModel.swift`:

```swift
import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedClub = "Все"

    // Состояние пагинации
    @Published var hasMore = false
    @Published var hasNew = false

    private var lastPostID: String?
    private var firstPostID: String?

    private let apiClient: APIClientProtocol
    private let limit = 20

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Public Methods

    func loadInitial() async {
        isLoading = true
        error = nil
        posts = []
        lastPostID = nil
        firstPostID = nil

        do {
            let response = try await apiClient.fetchPosts(
                club: selectedClub == "Все" ? nil : selectedClub,
                limit: limit,
                afterID: nil,
                beforeID: nil
            )

            posts = response.posts
            hasMore = response.hasMore
            hasNew = response.hasNew

            if let firstPost = posts.first {
                firstPostID = firstPost.id
            }
            if let lastPost = posts.last {
                lastPostID = lastPost.id
            }
        } catch {
            self.error = error.localizedDescription
            print("[FeedViewModel] loadInitial error: \(error)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading && hasMore && lastPostID != nil else { return }

        isLoading = true
        error = nil

        do {
            let response = try await apiClient.fetchPosts(
                club: selectedClub == "Все" ? nil : selectedClub,
                limit: limit,
                afterID: lastPostID,
                beforeID: nil
            )

            posts.append(contentsOf: response.posts)
            hasMore = response.hasMore
            hasNew = response.hasNew

            if let lastPost = posts.last {
                lastPostID = lastPost.id
            }
        } catch {
            self.error = error.localizedDescription
            print("[FeedViewModel] loadMore error: \(error)")
        }

        isLoading = false
    }

    func refresh() async {
        isLoading = true
        error = nil

        do {
            let response = try await apiClient.fetchPosts(
                club: selectedClub == "Все" ? nil : selectedClub,
                limit: limit,
                afterID: nil,
                beforeID: firstPostID
            )

            posts.insert(contentsOf: response.posts, at: 0)
            hasNew = response.hasNew

            if let firstPost = posts.first {
                firstPostID = firstPost.id
            }
        } catch {
            self.error = error.localizedDescription
            print("[FeedViewModel] refresh error: \(error)")
        }

        isLoading = false
    }

    func selectClub(_ club: String) async {
        selectedClub = club
        await loadInitial()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Petio-ios && xcodebuild test -scheme Petio -derivedDataPath build -only-testing Petio/FeedViewModelTests 2>&1 | tail -30
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Petio-ios/Petio/Features/Feed/FeedViewModel.swift Petio-ios/PetioTests/Features/Feed/FeedViewModelTests.swift
git commit -m "feat: add FeedViewModel with pagination logic and tests"
```

---

## Task 6: Update FeedView to use FeedViewModel with infinite scroll

**Files:**
- Modify: `Petio-ios/Petio/Features/Feed/FeedView.swift`

- [ ] **Step 1: Add ViewModel as @StateObject**

At the top of FeedView struct, after `@EnvironmentObject` declarations (around line 20), add:

```swift
@StateObject private var viewModel: FeedViewModel
```

Also add init method after the private properties:

```swift
init(apiClient: APIClientProtocol = HTTPAPIClient.shared) {
    _viewModel = StateObject(wrappedValue: FeedViewModel(apiClient: apiClient))
}
```

- [ ] **Step 2: Replace old posts state and filtering logic**

Find `private var filteredPosts` (around line 34). Replace the entire filteredPosts computed property with:

```swift
private var filteredPosts: [Post] {
    let base = viewModel.selectedClub == "Все" ? viewModel.posts : viewModel.posts.filter { $0.club == viewModel.selectedClub }
    return base.sorted {
        let d0 = parsePostDate($0.timestamp) ?? .distantPast
        let d1 = parsePostDate($1.timestamp) ?? .distantPast
        return newestFirst ? d0 > d1 : d0 < d1
    }
}
```

- [ ] **Step 3: Update selectedClub binding**

Find the selectedClub state variable (line 23, `@State private var selectedClub = "Все"`). Remove it entirely since viewModel now manages it. Update the ChipGroup binding (around line 52):

Find:
```swift
selection: $selectedClub
```

Replace with:
```swift
selection: $viewModel.selectedClub
```

- [ ] **Step 4: Add pull-to-refresh modifier**

Find the ScrollView (around line 54). After the LazyVStack closing brace and before the overlay, add:

```swift
.refreshable {
    await viewModel.refresh()
}
```

- [ ] **Step 5: Replace feed content with infinite scroll logic**

Find the feedContent view section (starts with `ScrollView` around line 54). Replace the entire ScrollView with:

```swift
ScrollView(showsIndicators: false) {
    LazyVStack(spacing: 12) {
        ForEach(Array(filteredPosts.enumerated()), id: \.element.id) { index, post in
            PostCard(post: post)
                .onAppear {
                    // Trigger loadMore when approaching last 3 posts
                    if filteredPosts.count - index <= 3 && !viewModel.isLoading && viewModel.hasMore {
                        Task {
                            await viewModel.loadMore()
                        }
                    }
                }
        }

        // Loading indicator at the bottom
        if viewModel.isLoading && !filteredPosts.isEmpty {
            ProgressView()
                .padding()
        }
    }
    .padding(.horizontal, 16)
}
.refreshable {
    await viewModel.refresh()
}
```

- [ ] **Step 6: Update initial load on appear**

Find `.onAppear` at the bottom of body (around line 96). Replace with:

```swift
.onAppear {
    if viewModel.posts.isEmpty {
        Task {
            await viewModel.loadInitial()
        }
    }
}
```

- [ ] **Step 7: Update error view**

Update the error condition (around line 46) to use viewModel error:

```swift
if viewModel.isLoading && viewModel.posts.isEmpty {
    ProgressView()
} else if viewModel.error != nil && viewModel.posts.isEmpty {
    errorView
} else {
    // ... rest of content
}
```

- [ ] **Step 8: Remove old posts loading logic**

Find and remove the `@State private var selectedClub = "Все"` line if still present.

- [ ] **Step 9: Build and verify**

```bash
cd Petio-ios && xcodebuild -scheme Petio -configuration Debug -derivedDataPath build 2>&1 | grep -E "error:" | head -10
```

Expected: No errors.

- [ ] **Step 10: Commit**

```bash
git add Petio-ios/Petio/Features/Feed/FeedView.swift
git commit -m "feat: integrate FeedViewModel with infinite scroll and pull-to-refresh"
```

---

## Task 7: Update AppContainer to inject FeedViewModel

**Files:**
- Modify: `Petio-ios/Petio/AppContainer.swift`

- [ ] **Step 1: Create FeedViewModel in container**

If AppContainer creates the HTTPAPIClient, verify it's accessible. Find where environment objects are set up (usually in a @main App or scene).

In the appropriate location (likely where environment objects are configured), ensure FeedViewModel can be created. Add to the app initialization if needed:

```swift
@StateObject private var feedViewModel = FeedViewModel(apiClient: HTTPAPIClient.shared)
```

And inject it:

```swift
.environmentObject(feedViewModel)
```

But since FeedView now creates its own ViewModel in init, you may not need this step. Verify FeedView compiles without changes to AppContainer.

- [ ] **Step 2: Verify HTTPAPIClient.shared exists**

Check if `HTTPAPIClient.shared` is a singleton in HTTPAPIClient.swift. If not, either:
- Add a `static let shared = HTTPAPIClient(authManager: AuthManager())`
- Or update FeedViewModel init to accept optional apiClient with a default

For now, assume shared instance exists or will be provided by dependency injection. If not, create it:

In `HTTPAPIClient.swift`, add after the class definition:

```swift
extension HTTPAPIClient {
    static let shared = HTTPAPIClient(authManager: AuthManager.shared)
}
```

Also ensure `AuthManager.shared` exists in `AuthManager.swift`.

- [ ] **Step 3: Build and test**

```bash
cd Petio-ios && xcodebuild -scheme Petio -configuration Debug -derivedDataPath build 2>&1 | grep -E "error:" | head -10
```

Expected: Build succeeds.

- [ ] **Step 4: Commit (if changes made)**

```bash
git add Petio-ios/Petio/AppContainer.swift Petio-ios/Petio/Core/Network/HTTPAPIClient.swift Petio-ios/Petio/Core/Auth/AuthManager.swift
git commit -m "chore: add HTTPAPIClient and AuthManager singletons for DI"
```

Or if no changes needed to AppContainer:

```bash
git commit --allow-empty -m "chore: AppContainer verified - no changes needed for FeedViewModel DI"
```

---

## Task 8: Run all tests and verify integration

**Files:**
- Test: `Petio-ios/PetioTests/Features/Feed/FeedViewModelTests.swift`
- Test: `Petio-ios/PetioTests/Integration/FeedIntegrationTests.swift` (if exists)

- [ ] **Step 1: Run FeedViewModel unit tests**

```bash
cd Petio-ios && xcodebuild test -scheme Petio -derivedDataPath build -only-testing Petio/FeedViewModelTests 2>&1 | tail -20
```

Expected: All tests PASS.

- [ ] **Step 2: Run all tests to ensure no regressions**

```bash
cd Petio-ios && xcodebuild test -scheme Petio -derivedDataPath build 2>&1 | grep -E "(Test Suite|passed|failed)" | tail -10
```

Expected: No new test failures.

- [ ] **Step 3: Build the app**

```bash
cd Petio-ios && xcodebuild -scheme Petio -configuration Debug -derivedDataPath build 2>&1 | tail -5
```

Expected: Build succeeds (BUILD COMPLETE).

- [ ] **Step 4: Commit test results**

```bash
git commit --allow-empty -m "test: verify all tests pass and integration working"
```

---

## Task 9: Manual testing checklist

- [ ] **Infinite scroll works:**
  - Launch app, go to Feed
  - Scroll to bottom — new posts load automatically
  - No duplicate posts appear

- [ ] **Pull-to-refresh works:**
  - Scroll to top and pull down
  - New posts appear at top with hasNew indicator

- [ ] **Club filter works:**
  - Select different clubs from chips
  - Posts reload for selected club
  - Pagination resets (no old posts from previous club)

- [ ] **Error handling:**
  - Disconnect network and try to load more
  - Error message displays, existing posts remain
  - Can retry by scrolling or pull-to-refresh

- [ ] **No performance issues:**
  - Scrolling is smooth
  - No memory leaks (check Xcode memory profiler)
  - App doesn't freeze on pagination

---

## Summary

| Task | Files Modified | Purpose |
|------|-----------------|---------|
| 1 | Endpoints.swift, HTTPAPIClient.swift | Update API host to 158.160.235.224 |
| 2 | Models.swift | Add PostsResponse model |
| 3 | APIClient.swift | Update fetchPosts protocol signature |
| 4 | HTTPAPIClient.swift | Implement new fetchPosts with pagination params |
| 5 | FeedViewModel.swift (new), FeedViewModelTests.swift (new) | Create ViewModel with pagination logic & tests |
| 6 | FeedView.swift | Integrate ViewModel with infinite scroll & pull-to-refresh |
| 7 | AppContainer.swift (if needed) | Setup dependency injection |
| 8 | Run all tests | Verify integration |
| 9 | Manual testing | Verify UX works correctly |

**Estimated commits:** 6-7 commits (one per major task)

---

## Success Criteria

✅ All 5 FeedViewModel unit tests pass
✅ No test regressions
✅ App builds without errors
✅ Infinite scroll loads posts smoothly
✅ Pull-to-refresh works
✅ Club filter works with new pagination
✅ Error handling works correctly
