# Email Registration Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement email registration with verification, blocking access to chat/posts/profile until email is verified.

**Architecture:** Simple State Machine in AuthManager + RegistrationState transitions in AuthViewModel. Device auth happens automatically on app launch. Email verified status stored in Keychain.

**Tech Stack:** SwiftUI, Foundation, Security framework (Keychain), async/await

---

## File Structure Overview

**Files to modify:**
- `Petio-ios/Petio/Core/Auth/AuthManager.swift` — add email verified status
- `Petio-ios/Petio/Features/Auth/AuthViewModel.swift` — new registration state machine
- `Petio-ios/Petio/Features/Chat/ChatView.swift` — add email verification gate
- `Petio-ios/Petio/Features/Feed/FeedView.swift` — add create post gate
- `Petio-ios/Petio/Features/Profile/ProfileView.swift` — add email verification gate
- `Petio-ios/Petio/PetioApp.swift` — automatic device auth on launch
- `Petio-ios/PetioTests/AuthManagerTests.swift` — expand tests

**Files to create:**
- `Petio-ios/Petio/Features/Auth/EmailRegistrationView.swift` — new email+password input screen
- `Petio-ios/Petio/Features/Auth/RegistrationState.swift` — registration state enum

**Files to delete:**
- `DeviceLoginView.swift`
- `LoginView.swift`
- `RegisterView.swift` (if it exists and uses old logic)
- `EmailLinkingPromptView.swift`
- `AuthPromptSheet.swift` (if not used elsewhere)

---

## Task Breakdown

### Task 1: Extend AuthManager with Email Verified Status

**Files:**
- Modify: `Petio-ios/Petio/Core/Auth/AuthManager.swift`

- [ ] **Step 1: Add email verified state**

Add these properties to AuthManager:

```swift
private let keychainEmailVerifiedAccount = "emailVerified"

@Published private(set) var isEmailVerified: Bool = false
```

Update `init()` to read email verified status:

```swift
init() {
    let hasToken = AuthManager.readFromKeychain(service: keychainService, account: keychainTokenAccount) != nil
    let emailVerified = AuthManager.readFromKeychain(service: keychainService, account: keychainEmailVerifiedAccount) == "true"
    self.isAuthenticated = hasToken
    self.isEmailVerified = emailVerified
}
```

- [ ] **Step 2: Add email verified setter method**

```swift
/// Set email verified status and persist to Keychain.
func setEmailVerified(_ verified: Bool) {
    print("[KEYCHAIN] setEmailVerified: \(verified)")
    if verified {
        saveToKeychain(service: keychainService, account: keychainEmailVerifiedAccount, value: "true")
    } else {
        deleteFromKeychain(service: keychainService, account: keychainEmailVerifiedAccount)
    }
    updateEmailVerified(verified)
}

/// Save email for current registration attempt (memory only).
private(set) var currentRegistrationEmail: String?

func setRegistrationEmail(_ email: String) {
    currentRegistrationEmail = email
}

func clearRegistrationEmail() {
    currentRegistrationEmail = nil
}
```

- [ ] **Step 3: Add email verified update method**

```swift
/// Update @Published property on main thread.
private func updateEmailVerified(_ value: Bool) {
    if Thread.isMainThread {
        isEmailVerified = value
    } else {
        DispatchQueue.main.async { self.isEmailVerified = value }
    }
}
```

- [ ] **Step 4: Update deleteToken to also clear email verified**

```swift
/// Remove tokens and email verified status, mark as unauthenticated.
func deleteToken() {
    deleteFromKeychain(service: keychainService, account: keychainTokenAccount)
    deleteFromKeychain(service: keychainService, account: keychainRefreshTokenAccount)
    deleteFromKeychain(service: keychainService, account: keychainEmailVerifiedAccount)
    updateAuth(false)
    updateEmailVerified(false)
}
```

- [ ] **Step 5: Commit**

```bash
git add Petio-ios/Petio/Core/Auth/AuthManager.swift
git commit -m "feat: add email verified status to AuthManager"
```

---

### Task 2: Create RegistrationState Enum

**Files:**
- Create: `Petio-ios/Petio/Features/Auth/RegistrationState.swift`

- [ ] **Step 1: Create file with enum**

```swift
//
//  RegistrationState.swift
//  Petio
//

import Foundation

enum RegistrationState: Equatable {
    case idle
    case enteringEmail
    case verifyingEmail
    case success
}
```

- [ ] **Step 2: Commit**

```bash
git add Petio-ios/Petio/Features/Auth/RegistrationState.swift
git commit -m "feat: add RegistrationState enum for registration flow"
```

---

### Task 3: Refactor AuthViewModel with New Registration Logic

**Files:**
- Modify: `Petio-ios/Petio/Features/Auth/AuthViewModel.swift`

- [ ] **Step 1: Add registration state and remove legacy methods**

Replace the entire AuthViewModel with this:

```swift
//
//  AuthViewModel.swift
//  Petio
//
//  Email-based registration with verification code.
//

import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var registrationState: RegistrationState = .idle
    @Published var isLoading = false
    @Published var errorMessage: String?

    let authManager: AuthManager
    private let deviceManager = DeviceManager.shared
    private let baseURL = "http://158.160.235.224/v1"

    init(authManager: AuthManager) {
        print("[AUTH_VM] initializing with authManager.isAuthenticated=\(authManager.isAuthenticated)")
        self.authManager = authManager
    }

    var isAuthenticated: Bool {
        authManager.isAuthenticated
    }

    var isEmailVerified: Bool {
        authManager.isEmailVerified
    }

    // MARK: - Registration Flow

    func startRegistration() {
        print("[AUTH] startRegistration: entering email input")
        registrationState = .enteringEmail
        errorMessage = nil
    }

    func linkEmail(email: String, password: String) async {
        print("[AUTH] linkEmail: starting with email=\(email)")
        isLoading = true
        errorMessage = nil

        do {
            // Save email to remember where we are if user closes sheet
            authManager.setRegistrationEmail(email)

            // Call backend to send verification code
            struct Request: Encodable {
                let email: String
                let password: String
            }
            struct Response: Decodable {
                let status: String
            }

            let _: Response = try await apiRequest(
                path: "/auth/link-email",
                method: "POST",
                body: Request(email: email, password: password)
            )

            print("[AUTH] linkEmail: success, moving to verification")
            registrationState = .verifyingEmail

        } catch {
            print("[AUTH] linkEmail failed: \(error)")
            errorMessage = describe(error)
            isLoading = false
        }
    }

    func verifyEmail(code: String) async {
        print("[AUTH] verifyEmail: sending code=\(code)")
        isLoading = true
        errorMessage = nil

        do {
            struct Request: Encodable {
                let code: String
            }
            struct Response: Decodable {
                let status: String
            }

            let _: Response = try await apiRequest(
                path: "/auth/verify-email",
                method: "POST",
                body: Request(code: code)
            )

            print("[AUTH] verifyEmail: success, marking as verified")
            authManager.setEmailVerified(true)
            authManager.clearRegistrationEmail()
            registrationState = .success
            isLoading = false

        } catch {
            print("[AUTH] verifyEmail failed: \(error)")
            errorMessage = describe(error)
            isLoading = false
        }
    }

    func cancelRegistration() {
        print("[AUTH] cancelRegistration: clearing state")
        registrationState = .idle
        errorMessage = nil
        authManager.clearRegistrationEmail()
    }

    // MARK: - Generic API Request Helper

    private func apiRequest<T: Decodable, B: Encodable>(
        path: String,
        method: String = "GET",
        body: B? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authManager.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.network(URLError(.badServerResponse)) }
        guard (200..<300).contains(http.statusCode) else { throw APIError.server(http.statusCode) }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Error Handling

    private func describe(_ error: Error) -> String {
        guard let apiError = error as? APIError else {
            return "Произошла ошибка. Попробуйте ещё раз."
        }
        switch apiError {
        case .server(401): return "Неверные учётные данные."
        case .server(409): return "Этот email уже используется."
        case .server(let code): return "Ошибка сервера: \(code)."
        case .network: return "Нет подключения к интернету."
        default: return "Произошла ошибка. Попробуйте ещё раз."
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Petio-ios/Petio/Features/Auth/AuthViewModel.swift
git commit -m "feat: refactor AuthViewModel with new registration state machine"
```

---

### Task 4: Create EmailRegistrationView

**Files:**
- Create: `Petio-ios/Petio/Features/Auth/EmailRegistrationView.swift`

- [ ] **Step 1: Create email + password input view**

```swift
//
//  EmailRegistrationView.swift
//  Petio
//
//  Email and password input for registration.
//

import SwiftUI

struct EmailRegistrationView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @Environment(\.dismiss) private var dismiss

    var isValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        email.contains("@")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Создайте аккаунт")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Пароль", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)

                    SecureField("Подтвердите пароль", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                }

                if !viewModel.errorMessage?.isEmpty ?? false {
                    Text(viewModel.errorMessage ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.linkEmail(email: email, password: password)
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        Text("Продолжить")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .background(isValid && !viewModel.isLoading ? PetCareTheme.primary : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(!isValid || viewModel.isLoading)

                Button {
                    dismiss()
                } label: {
                    Text("Отмена")
                        .font(.system(size: 16))
                        .foregroundColor(PetCareTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .background(PetCareTheme.background)
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    EmailRegistrationView()
        .environmentObject(AuthViewModel(authManager: AuthManager()))
}
```

- [ ] **Step 2: Commit**

```bash
git add Petio-ios/Petio/Features/Auth/EmailRegistrationView.swift
git commit -m "feat: create EmailRegistrationView for email+password input"
```

---

### Task 5: Update EmailVerificationView for New Flow

**Files:**
- Modify: `Petio-ios/Petio/Features/Auth/EmailVerificationView.swift`

- [ ] **Step 1: Read current EmailVerificationView**

First, read the existing file to see what's there:

```bash
head -100 Petio-ios/Petio/Features/Auth/EmailVerificationView.swift
```

- [ ] **Step 2: Update to work with new AuthViewModel**

Assuming the file exists, update it to use the new `verifyEmail` method:

```swift
//
//  EmailVerificationView.swift
//  Petio
//
//  Email verification code input.
//

import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @State private var code = ""
    @State private var timeRemaining = 900 // 15 minutes
    @State private var timer: Timer?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Подтвердите email")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Мы отправили код на вашу почту")
                .font(.system(size: 14))
                .foregroundColor(PetCareTheme.muted)

            TextField("Введите 6-значный код", text: $code)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .onChange(of: code) { _, newValue in
                    code = String(newValue.prefix(6))
                }

            if !viewModel.errorMessage?.isEmpty ?? false {
                Text(viewModel.errorMessage ?? "")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            HStack {
                Text("Код действителен: \(formatTime(timeRemaining))")
                    .font(.system(size: 12))
                    .foregroundColor(timeRemaining < 60 ? .red : PetCareTheme.muted)

                Spacer()

                if timeRemaining > 0 {
                    Text("Отправить ещё")
                        .font(.system(size: 12))
                        .foregroundColor(PetCareTheme.primary)
                        .onTapGesture {
                            // TODO: implement requestNewCode
                        }
                }
            }
            .padding(.top, 8)

            Spacer()

            Button {
                Task {
                    await viewModel.verifyEmail(code: code)
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text("Подтвердить")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .background(code.count == 6 && !viewModel.isLoading ? PetCareTheme.primary : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(code.count != 6 || viewModel.isLoading)

            Button {
                dismiss()
            } label: {
                Text("Отмена")
                    .font(.system(size: 16))
                    .foregroundColor(PetCareTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .background(PetCareTheme.background)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

#Preview {
    EmailVerificationView()
        .environmentObject(AuthViewModel(authManager: AuthManager()))
}
```

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/Petio/Features/Auth/EmailVerificationView.swift
git commit -m "feat: update EmailVerificationView for new registration flow"
```

---

### Task 6: Add Email Verification Gate to ChatView

**Files:**
- Modify: `Petio-ios/Petio/Features/Chat/ChatView.swift`

- [ ] **Step 1: Update ChatView body to check isEmailVerified**

Replace the current body with:

```swift
var body: some View {
    if authManager.isEmailVerified {
        VStack(spacing: 0) {
            chatHeader
            messagesList
            inputBar
        }
        .background(PetCareTheme.background)
    } else {
        authPromptView
    }
}
```

- [ ] **Step 2: Update authPromptView to show registration flow**

Replace authPromptView:

```swift
private var authPromptView: some View {
    VStack(spacing: 20) {
        Spacer()

        Image(systemName: "lock.fill")
            .font(.system(size: 60))
            .foregroundColor(PetCareTheme.primary)

        Text("AI-помощник требует аккаунта")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)

        Text("Создайте аккаунт с подтверждением email, чтобы общаться с AI-помощником")
            .font(.system(size: 16))
            .foregroundColor(PetCareTheme.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        Spacer()

        VStack(spacing: 12) {
            if authViewModel.registrationState == .idle {
                Button {
                    authViewModel.startRegistration()
                } label: {
                    Text("Создать аккаунт")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(PetCareTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else if authViewModel.registrationState == .enteringEmail {
                EmailRegistrationView()
                    .environmentObject(authViewModel)
            } else if authViewModel.registrationState == .verifyingEmail {
                EmailVerificationView()
                    .environmentObject(authViewModel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
    .background(PetCareTheme.background)
}
```

- [ ] **Step 3: Add authViewModel property**

At the top of ChatView struct, add:

```swift
@StateObject private var authViewModel: AuthViewModel

init() {
    _authViewModel = StateObject(wrappedValue: AuthViewModel(authManager: AuthManager.shared))
}
```

- [ ] **Step 4: Update onChange listener**

```swift
.onChange(of: authManager.isEmailVerified) { _, isVerified in
    if isVerified {
        authViewModel.registrationState = .success
        authViewModel.cancelRegistration()
        // Return to chat (already showing because isEmailVerified = true)
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add Petio-ios/Petio/Features/Chat/ChatView.swift
git commit -m "feat: add email verification gate to ChatView"
```

---

### Task 7: Add Email Verification Gate to ProfileView

**Files:**
- Modify: `Petio-ios/Petio/Features/Profile/ProfileView.swift`

- [ ] **Step 1: Read ProfileView to understand current structure**

```bash
head -80 Petio-ios/Petio/Features/Profile/ProfileView.swift
```

- [ ] **Step 2: Add verification check**

Add at the beginning of ProfileView body:

```swift
var body: some View {
    if authManager.isEmailVerified {
        // existing profile content
        scrollableContent
    } else {
        profileLockedView
    }
}

private var profileLockedView: some View {
    VStack(spacing: 20) {
        Spacer()

        Image(systemName: "lock.fill")
            .font(.system(size: 60))
            .foregroundColor(PetCareTheme.primary)

        Text("Профиль требует аккаунта")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)

        Text("Создайте аккаунт с подтверждением email")
            .font(.system(size: 16))
            .foregroundColor(PetCareTheme.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

        Spacer()

        Button {
            showAuthView = true
        } label: {
            Text("Создать аккаунт")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PetCareTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
    .background(PetCareTheme.background)
}

@State private var showAuthView = false

.fullScreenCover(isPresented: $showAuthView) {
    AuthView()
}
```

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/Petio/Features/Profile/ProfileView.swift
git commit -m "feat: add email verification gate to ProfileView"
```

---

### Task 8: Add Create Post Gate to FeedView

**Files:**
- Modify: `Petio-ios/Petio/Features/Feed/FeedView.swift`

- [ ] **Step 1: Read FeedView and find NewPostSheet**

```bash
grep -n "NewPostSheet" Petio-ios/Petio/Features/Feed/FeedView.swift
```

- [ ] **Step 2: Update sheet presentation logic**

Find where NewPostSheet is presented and change:

```swift
// OLD:
.sheet(isPresented: $showNewPost) {
    NewPostSheet()
}

// NEW:
.sheet(isPresented: $showNewPost) {
    if authManager.isEmailVerified {
        NewPostSheet()
    } else {
        Text("Требуется подтверждение email для создания постов")
            .padding()
    }
}
```

Or better, disable the button:

```swift
Button {
    if authManager.isEmailVerified {
        showNewPost = true
    } else {
        showAuthError = true
    }
} label: {
    Image(systemName: "square.and.pencil")
}
.disabled(!authManager.isEmailVerified)

.sheet(isPresented: $showAuthError) {
    VStack {
        Text("Создание поста требует верифицированный аккаунт")
        Button("Создать аккаунт") {
            showAuthView = true
        }
    }
}

.fullScreenCover(isPresented: $showAuthView) {
    AuthView()
}

@State private var showAuthError = false
@State private var showAuthView = false
```

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/Petio/Features/Feed/FeedView.swift
git commit -m "feat: restrict post creation to verified users"
```

---

### Task 9: Implement Automatic Device Auth on App Launch

**Files:**
- Modify: `Petio-ios/Petio/PetioApp.swift` (or App.swift)

- [ ] **Step 1: Read current App structure**

```bash
head -100 Petio-ios/Petio/PetioApp.swift
```

- [ ] **Step 2: Add device auth on app launch**

Add to PetioApp or App:

```swift
@main
struct PetioApp: App {
    @StateObject private var authManager = AuthManager.shared
    @State private var isDeviceAuthComplete = false

    var body: some Scene {
        WindowGroup {
            if isDeviceAuthComplete {
                HomeView()
                    .environmentObject(authManager)
            } else {
                ProgressView()
                    .onAppear {
                        Task {
                            await performDeviceAuth()
                        }
                    }
            }
        }
    }

    private func performDeviceAuth() async {
        print("[APP] Starting device auth...")
        do {
            // Get or create device ID
            let deviceManager = DeviceManager.shared
            let deviceID = try await deviceManager.getDeviceID()

            // Device login
            let response = try await deviceLogin(deviceID: deviceID)

            // Save token
            authManager.saveToken(response.token)
            authManager.saveRefreshToken(response.refreshToken)

            print("[APP] Device auth complete")
            isDeviceAuthComplete = true
        } catch {
            print("[APP] Device auth failed: \(error)")
            // Still allow app to load even if device auth fails
            isDeviceAuthComplete = true
        }
    }

    private func deviceLogin(deviceID: String) async throws -> DeviceLoginResponse {
        struct Request: Encodable {
            let device_id: String
        }
        struct Response: Decodable {
            let token: String
            let refreshToken: String
            let userId: String
            let isNew: Bool
        }

        let baseURL = "http://158.160.235.224/v1"
        guard let url = URL(string: baseURL + "/auth/device") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(Request(device_id: deviceID))

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(http.statusCode)
        }

        let decodedResponse = try JSONDecoder().decode(Response.self, from: data)
        return DeviceLoginResponse(
            token: decodedResponse.token,
            refreshToken: decodedResponse.refreshToken,
            userId: decodedResponse.userId,
            isNew: decodedResponse.isNew
        )
    }
}

private struct DeviceLoginResponse {
    let token: String
    let refreshToken: String
    let userId: String
    let isNew: Bool
}
```

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/Petio/PetioApp.swift
git commit -m "feat: add automatic device auth on app launch"
```

---

### Task 10: Delete Legacy Auth Screens

**Files:**
- Delete: `DeviceLoginView.swift`
- Delete: `LoginView.swift`
- Delete: `RegisterView.swift`
- Delete: `EmailLinkingPromptView.swift`

- [ ] **Step 1: Delete files**

```bash
rm Petio-ios/Petio/Features/Auth/DeviceLoginView.swift
rm Petio-ios/Petio/Features/Auth/LoginView.swift
rm Petio-ios/Petio/Features/Auth/RegisterView.swift
rm Petio-ios/Petio/Features/Auth/EmailLinkingPromptView.swift
```

- [ ] **Step 2: Check for imports of deleted files**

```bash
grep -r "DeviceLoginView\|LoginView\|RegisterView\|EmailLinkingPromptView" Petio-ios/Petio/ --include="*.swift"
```

- [ ] **Step 3: Remove any found imports**

Edit any files that import these deleted views and remove the imports.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: remove legacy auth screens"
```

---

### Task 11: Expand AuthManager Tests

**Files:**
- Modify: `Petio-ios/PetioTests/AuthManagerTests.swift`

- [ ] **Step 1: Read existing tests**

```bash
head -150 Petio-ios/PetioTests/AuthManagerTests.swift
```

- [ ] **Step 2: Add email verified tests**

Add these test methods:

```swift
func testSaveAndGetEmailVerified() {
    let authManager = AuthManager()

    // Initially not verified
    XCTAssertFalse(authManager.isEmailVerified)

    // Save as verified
    authManager.setEmailVerified(true)
    XCTAssertTrue(authManager.isEmailVerified)

    // Save as not verified
    authManager.setEmailVerified(false)
    XCTAssertFalse(authManager.isEmailVerified)
}

func testRegistrationEmailStorage() {
    let authManager = AuthManager()

    // Initially empty
    XCTAssertNil(authManager.currentRegistrationEmail)

    // Save email
    authManager.setRegistrationEmail("test@example.com")
    XCTAssertEqual(authManager.currentRegistrationEmail, "test@example.com")

    // Clear email
    authManager.clearRegistrationEmail()
    XCTAssertNil(authManager.currentRegistrationEmail)
}

func testDeleteTokenClearsEmailVerified() {
    let authManager = AuthManager()

    // Set up
    authManager.saveToken("test_token")
    authManager.setEmailVerified(true)
    XCTAssertTrue(authManager.isEmailVerified)

    // Delete
    authManager.deleteToken()

    // Verify cleanup
    XCTAssertNil(authManager.getToken())
    XCTAssertFalse(authManager.isEmailVerified)
}
```

- [ ] **Step 3: Run tests**

```bash
cd Petio-ios
xcodebuild test -scheme Petio -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected output: All tests pass

- [ ] **Step 4: Commit**

```bash
git add Petio-ios/PetioTests/AuthManagerTests.swift
git commit -m "test: add email verified status tests to AuthManager"
```

---

### Task 12: Integration Test for Registration Flow

**Files:**
- Create: `Petio-ios/PetioTests/Integration/RegistrationFlowIntegrationTests.swift`

- [ ] **Step 1: Create integration test file**

```swift
//
//  RegistrationFlowIntegrationTests.swift
//  PetioTests
//

import XCTest
@testable import Petio

class RegistrationFlowIntegrationTests: XCTestCase {

    var authManager: AuthManager!
    var authViewModel: AuthViewModel!

    override func setUp() {
        super.setUp()
        authManager = AuthManager()
        authViewModel = AuthViewModel(authManager: authManager)
    }

    @MainActor
    func testRegistrationStateFlow() {
        // Initial state
        XCTAssertEqual(authViewModel.registrationState, .idle)

        // Start registration
        authViewModel.startRegistration()
        XCTAssertEqual(authViewModel.registrationState, .enteringEmail)

        // Cancel
        authViewModel.cancelRegistration()
        XCTAssertEqual(authViewModel.registrationState, .idle)
    }

    @MainActor
    func testEmailSaved() {
        authViewModel.startRegistration()

        // Save email
        authManager.setRegistrationEmail("user@example.com")

        XCTAssertEqual(authManager.currentRegistrationEmail, "user@example.com")
    }

    @MainActor
    func testEmailVerifiedAfterSuccess() {
        XCTAssertFalse(authManager.isEmailVerified)

        authManager.setEmailVerified(true)

        XCTAssertTrue(authManager.isEmailVerified)
    }
}
```

- [ ] **Step 2: Run test**

```bash
cd Petio-ios
xcodebuild test -scheme Petio -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:PetioTests/RegistrationFlowIntegrationTests
```

Expected: Tests pass

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/PetioTests/Integration/RegistrationFlowIntegrationTests.swift
git commit -m "test: add registration flow integration tests"
```

---

### Task 13: Manual Testing of Complete Flow

- [ ] **Step 1: Clean build**

```bash
cd Petio-ios
xcodebuild clean -scheme Petio
```

- [ ] **Step 2: Build and run**

```bash
xcodebuild build -scheme Petio -destination 'platform=iOS Simulator,name=iPhone 15'
open Petio.app  # or use Xcode to run
```

- [ ] **Step 3: Test device auth**

- Open app
- Should show loading spinner then main screen
- No visible auth prompts if device auth succeeds

- [ ] **Step 4: Test chat protection**

- Tap Chat tab
- Should see "AI-помощник требует аккаунта" message
- Tap "Создать аккаунт" button

- [ ] **Step 5: Test email registration**

- Should see EmailRegistrationView with email + password fields
- Enter test@example.com and password
- Tap "Продолжить"
- Should transition to EmailVerificationView

- [ ] **Step 6: Verify in backend logs**

- Check backend logs for POST /auth/link-email
- Confirm email was received (or check logs for code if SMTP not configured)

- [ ] **Step 7: Test email verification**

- Get code from backend logs
- Enter code in verification screen
- Tap "Подтвердить"
- Should return to Chat view (now unblocked)

- [ ] **Step 8: Test profile protection**

- Tap Profile tab
- Should show lock screen (or allow read but block edit)
- Similar flow to chat

- [ ] **Step 9: Test post creation protection**

- Go to Feed tab
- Try to create post
- Should see restriction message

- [ ] **Step 10: Verify Keychain persistence**

- Kill app
- Reopen app
- Should load with email verified status still set
- Chat/Profile should be accessible

---

## Summary

This plan implements:
1. ✅ AuthManager email verified status + Keychain persistence
2. ✅ RegistrationState enum for state machine
3. ✅ AuthViewModel new registration logic with linkEmail/verifyEmail
4. ✅ EmailRegistrationView for email+password input
5. ✅ EmailVerificationView improvements
6. ✅ ChatView protection (email verification gate)
7. ✅ ProfileView protection
8. ✅ FeedView post creation restriction
9. ✅ Automatic device auth on app launch
10. ✅ Legacy code removal
11. ✅ Unit and integration tests
12. ✅ Manual testing

All tasks use TDD where applicable with frequent, focused commits.
