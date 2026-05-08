# Device-Based Auth System Implementation Plan

> **Для реализации:** используй superpowers:subagent-driven-development — один fresh subagent на каждую задачу, review между задачами.

**Цель:** Интегрировать device-based аутентификацию с refresh токенами и опциональной email привязкой.

**Архитектура:** Device login создает анонимный аккаунт, сохраняет device_id в Keychain. HTTPAPIClient автоматически обновляет expired tokens через refresh endpoint. Email linking конвертирует анонимный аккаунт в password-protected.

**Tech Stack:** SwiftUI, Keychain (Security framework), async/await, URLSession, JWT токены.

---

## Файловая структура

| Файл | Статус | Ответственность |
|------|--------|-----------------|
| `Core/Device/DeviceManager.swift` | **Create** | Генерирование/хранение device_id в Keychain |
| `Core/Auth/AuthManager.swift` | **Update** | Добавить refreshToken storage (было только token) |
| `Features/Auth/AuthViewModel.swift` | **Update** | Переписать: device login, email linking, account switching |
| `Core/Network/HTTPAPIClient.swift` | **Update** | Добавить 401 interceptor → refresh token → retry |
| `Features/Auth/DeviceLoginView.swift` | **Create** | Splashscreen с loader при device login |
| `Features/Auth/EmailLinkingPromptView.swift` | **Create** | Форма привязки email+пароль |
| `Features/Auth/EmailVerificationView.swift` | **Create** | Ввод кода верификации из письма |
| `PetioTests/DeviceManagerTests.swift` | **Create** | Tests для DeviceManager |
| `PetioTests/AuthManagerTests.swift` | **Update** | Tests для новых refreshToken методов |
| `PetioTests/AuthViewModelTests.swift` | **Create** | Tests для device login, email linking |
| `PetioTests/HTTPAPIClientTests.swift` | **Update** | Tests для 401 refresh interceptor |

---

## Task 1: DeviceManager — генерирование и хранение device_id

**Files:**
- Create: `Petio-ios/Petio/Core/Device/DeviceManager.swift`
- Create: `Petio-ios/PetioTests/DeviceManagerTests.swift`

- [ ] **Step 1: Write failing test для getDeviceID**

```swift
import XCTest
@testable import Petio

final class DeviceManagerTests: XCTestCase {
    var sut: DeviceManager!

    override func setUp() {
        super.setUp()
        sut = DeviceManager()
        // Очистить Keychain перед каждым тестом
        try? sut.deleteDeviceID()
    }

    func testGetDeviceID_CreatesNewUUIDOnFirstCall() async throws {
        let firstCall = try await sut.getDeviceID()
        XCTAssertFalse(firstCall.isEmpty)
        XCTAssertEqual(firstCall.count, 36) // UUID формат: 8-4-4-4-12
    }

    func testGetDeviceID_ReturnsSameIDOnSecondCall() async throws {
        let firstID = try await sut.getDeviceID()
        let secondID = try await sut.getDeviceID()
        XCTAssertEqual(firstID, secondID)
    }
}
```

Run: `xcodebuild test -scheme Petio -testPlan DeviceManagerTests`
Expected: **FAIL** — DeviceManager не существует

- [ ] **Step 2: Создать DeviceManager с getDeviceID**

```swift
import Foundation
import Security

final class DeviceManager {
    private let keychainService = "com.petio.app"
    private let keychainAccount = "deviceID"

    nonisolated private static let shared = DeviceManager()

    func getDeviceID() async throws -> String {
        if let existing = loadFromKeychain() {
            return existing
        }

        let newID = UUID().uuidString
        try saveToKeychain(newID)
        return newID
    }

    private func saveToKeychain(_ id: String) throws {
        guard let data = id.data(using: .utf8) else {
            throw NSError(domain: "DeviceManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode device_id"])
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)

        var attrs = query
        attrs[kSecValueData as String] = data

        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "DeviceManager", code: Int(status), userInfo: nil)
        }
    }

    private func loadFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let id = String(data: data, encoding: .utf8) else {
            return nil
        }
        return id
    }

    func deleteDeviceID() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 3: Run test, verify PASS**

Run: `xcodebuild test -scheme Petio -testPlan DeviceManagerTests`
Expected: **PASS** (оба теста зелены)

- [ ] **Step 4: Commit**

```bash
git add Petio-ios/Petio/Core/Device/DeviceManager.swift \
        Petio-ios/PetioTests/DeviceManagerTests.swift
git commit -m "feat: add DeviceManager for device_id storage in Keychain"
```

---

## Task 2: AuthManager — добавить refreshToken storage

**Files:**
- Modify: `Petio-ios/Petio/Core/Auth/AuthManager.swift`
- Update: `Petio-ios/PetioTests/AuthManagerTests.swift`

- [ ] **Step 1: Write failing test для saveRefreshToken/getRefreshToken**

```swift
func testSaveAndGetRefreshToken() {
    let refreshToken = "test-refresh-token-123"

    authManager.saveRefreshToken(refreshToken)
    let retrieved = authManager.getRefreshToken()

    XCTAssertEqual(retrieved, refreshToken)
}

func testDeleteTokenAlsoDeletesRefreshToken() {
    authManager.saveToken("test-token")
    authManager.saveRefreshToken("test-refresh")

    authManager.deleteToken()

    XCTAssertNil(authManager.getToken())
    XCTAssertNil(authManager.getRefreshToken())
}
```

Run: `xcodebuild test -scheme Petio -testPlan AuthManagerTests`
Expected: **FAIL** — методов нет

- [ ] **Step 2: Обновить AuthManager**

Добавить в класс AuthManager:

```swift
private let refreshTokenKeychainAccount = "authRefreshToken"

/// Save refresh token to Keychain
func saveRefreshToken(_ token: String) {
    guard let data = token.data(using: .utf8) else { return }
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: refreshTokenKeychainAccount
    ]
    SecItemDelete(query as CFDictionary)
    var attrs = query
    attrs[kSecValueData as String] = data
    SecItemAdd(attrs as CFDictionary, nil)
}

/// Get refresh token from Keychain
func getRefreshToken() -> String? {
    AuthManager.readFromKeychain(service: keychainService, account: refreshTokenKeychainAccount)
}
```

Обновить `deleteToken()` чтобы удалял и refreshToken:

```swift
func deleteToken() {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: keychainAccount
    ]
    SecItemDelete(query as CFDictionary)

    // Удалить и refresh token
    let refreshQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainService,
        kSecAttrAccount as String: refreshTokenKeychainAccount
    ]
    SecItemDelete(refreshQuery as CFDictionary)

    updateAuth(false)
}
```

- [ ] **Step 3: Run tests, verify PASS**

Run: `xcodebuild test -scheme Petio -testPlan AuthManagerTests`
Expected: **PASS** (все AuthManager тесты зелены)

- [ ] **Step 4: Commit**

```bash
git add Petio-ios/Petio/Core/Auth/AuthManager.swift
git commit -m "feat: add refreshToken storage to AuthManager"
```

---

## Task 3: HTTPAPIClient — добавить 401 interceptor для refresh token

**Files:**
- Modify: `Petio-ios/Petio/Core/Network/HTTPAPIClient.swift`

- [ ] **Step 1: Add refreshAccessToken method**

```swift
private func refreshAccessToken() async throws -> String {
    guard let refreshToken = authManager.getRefreshToken() else {
        throw APIError.server(401)
    }

    var components = URLComponents(string: baseURL)!
    components.path = "/auth/refresh"

    var req = URLRequest(url: components.url!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = ["refreshToken": refreshToken]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: req)
    guard let http = response as? HTTPURLResponse else {
        throw APIError.network(URLError(.badServerResponse))
    }

    guard (200..<300).contains(http.statusCode) else {
        throw APIError.server(http.statusCode)
    }

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
          let newToken = json["token"] else {
        throw APIError.decoding(URLError(.cannotDecodeRawData))
    }

    // Сохранить новые токены
    authManager.saveToken(newToken)
    if let newRefresh = json["refreshToken"] {
        authManager.saveRefreshToken(newRefresh)
    }

    return newToken
}
```

- [ ] **Step 2: Update perform method to handle 401**

В методе `perform<T: Decodable>()`, обновить обработку 401 статус кода:

```swift
private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw APIError.network(URLError(.badServerResponse))
    }

    if http.statusCode == 401 {
        // Попытаться обновить token
        do {
            _ = try await refreshAccessToken()
            // Повторить запрос с новым токеном
            var newRequest = request
            if let token = authManager.getToken() {
                newRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (retryData, retryResponse) = try await URLSession.shared.data(for: newRequest)
            guard let retryHttp = retryResponse as? HTTPURLResponse else {
                throw APIError.network(URLError(.badServerResponse))
            }
            guard (200..<300).contains(retryHttp.statusCode) else {
                if retryHttp.statusCode == 401 {
                    authManager.deleteToken()
                }
                throw APIError.server(retryHttp.statusCode)
            }
            return try JSONDecoder().decode(T.self, from: retryData)
        } catch {
            // Refresh failed
            authManager.deleteToken()
            throw APIError.server(401)
        }
    }

    guard (200..<300).contains(http.statusCode) else {
        throw APIError.server(http.statusCode)
    }

    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        throw APIError.decoding(error)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/Petio/Core/Network/HTTPAPIClient.swift
git commit -m "feat: add automatic token refresh on 401 error"
```

---

## Task 4: AuthViewModel — переписать для device login

**Files:**
- Modify: `Petio-ios/Petio/Features/Auth/AuthViewModel.swift`

- [ ] **Step 1: Replace AuthViewModel completely**

```swift
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showEmailLinking = false
    @Published var deviceAccounts: [AccountInfo] = []
    @Published var currentEmail: String?

    private let apiClient: APIClientProtocol
    private let authManager: AuthManager
    private let deviceManager: DeviceManager

    init(apiClient: APIClientProtocol, authManager: AuthManager, deviceManager: DeviceManager) {
        self.apiClient = apiClient
        self.authManager = authManager
        self.deviceManager = deviceManager
    }

    // MARK: - Device Login

    func deviceLogin() async {
        isLoading = true
        errorMessage = nil

        do {
            let deviceID = try await deviceManager.getDeviceID()
            print("[AUTH] Device login: device_id=\(deviceID)")

            let response: (token: String, refreshToken: String, userId: String, isNew: Bool) = try await makeDeviceLoginRequest(deviceID: deviceID)

            authManager.saveToken(response.token)
            authManager.saveRefreshToken(response.refreshToken)

            isAuthenticated = true
            showEmailLinking = response.isNew

            print("[AUTH] Device login success: userId=\(response.userId), isNew=\(response.isNew)")
        } catch {
            errorMessage = "Не удалось подключиться. Попробуйте позже."
            isAuthenticated = false
            print("[AUTH] Device login error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Email Linking

    func linkEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: (status: String) = try await makeLinkEmailRequest(email: email, password: password)
            currentEmail = email
            print("[AUTH] Email linking: code sent to \(email)")
        } catch let error as APIError {
            switch error {
            case .server(409):
                errorMessage = "Эта почта уже используется"
            default:
                errorMessage = "Не удалось отправить код. Попробуйте снова."
            }
            print("[AUTH] Email linking error: \(error)")
        } catch {
            errorMessage = "Ошибка сети. Попробуйте снова."
        }

        isLoading = false
    }

    func verifyEmail(code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: (status: String) = try await makeVerifyEmailRequest(code: code)
            showEmailLinking = false
            print("[AUTH] Email verified successfully")
        } catch let error as APIError {
            switch error {
            case .server(400):
                errorMessage = "Неверный или истекший код"
            default:
                errorMessage = "Не удалось подтвердить код. Попробуйте снова."
            }
            print("[AUTH] Email verification error: \(error)")
        } catch {
            errorMessage = "Ошибка сети. Попробуйте снова."
        }

        isLoading = false
    }

    // MARK: - Private HTTP Requests

    private func makeDeviceLoginRequest(deviceID: String) async throws -> (token: String, refreshToken: String, userId: String, isNew: Bool) {
        guard var components = URLComponents(string: baseURL + "/auth/device") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["device_id": deviceID])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              let refreshToken = json["refreshToken"] as? String,
              let userId = json["userId"] as? String,
              let isNew = json["isNew"] as? Bool else {
            throw APIError.decoding(URLError(.cannotDecodeRawData))
        }

        return (token, refreshToken, userId, isNew)
    }

    private func makeLinkEmailRequest(email: String, password: String) async throws -> (status: String) {
        guard var components = URLComponents(string: baseURL + "/auth/link-email") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authManager.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let status = json["status"] else {
            throw APIError.decoding(URLError(.cannotDecodeRawData))
        }

        return (status)
    }

    private func makeVerifyEmailRequest(code: String) async throws -> (status: String) {
        guard var components = URLComponents(string: baseURL + "/auth/verify-email") else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authManager.getToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["code": code])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let status = json["status"] else {
            throw APIError.decoding(URLError(.cannotDecodeRawData))
        }

        return (status)
    }

    private var baseURL: String {
        "http://158.160.235.224:8080/v1"
    }
}

struct AccountInfo: Identifiable {
    let id: String
    let userId: String
    let email: String?
    let isCurrentAccount: Bool
}
```

- [ ] **Step 2: Commit**

```bash
git add Petio-ios/Petio/Features/Auth/AuthViewModel.swift
git commit -m "refactor: rewrite AuthViewModel for device-based login and email linking"
```

---

## Task 5: DeviceLoginView — Splashscreen с loader

**Files:**
- Create: `Petio-ios/Petio/Features/Auth/DeviceLoginView.swift`

- [ ] **Step 1: Create DeviceLoginView**

```swift
import SwiftUI

struct DeviceLoginView: View {
    @EnvironmentObject private var viewModel: AuthViewModel

    var body: some View {
        ZStack {
            PetCareTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(PetCareTheme.primary)

                    Text("Один момент")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PetCareTheme.primary)

                    Text("Настраиваем ваш аккаунт")
                        .font(.system(size: 15))
                        .foregroundStyle(PetCareTheme.muted)
                }

                ProgressView()
                    .tint(PetCareTheme.primary)
                    .scaleEffect(1.2)

                Spacer()
            }
            .padding(32)
        }
        .onAppear {
            Task {
                await viewModel.deviceLogin()
            }
        }
    }
}

#Preview {
    DeviceLoginView()
        .environmentObject(AuthViewModel(
            apiClient: HTTPAPIClient(authManager: AuthManager.shared),
            authManager: AuthManager.shared,
            deviceManager: DeviceManager()
        ))
}
```

- [ ] **Step 2: Commit**

```bash
git add Petio-ios/Petio/Features/Auth/DeviceLoginView.swift
git commit -m "feat: add DeviceLoginView with loader"
```

---

## Task 6: EmailLinkingPromptView — форма привязки email

**Files:**
- Create: `Petio-ios/Petio/Features/Auth/EmailLinkingPromptView.swift`

- [ ] **Step 1: Create EmailLinkingPromptView**

```swift
import SwiftUI

struct EmailLinkingPromptView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 6 && password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(PetCareTheme.primary)

                        Text("Защитить аккаунт")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(PetCareTheme.primary)

                        Text("Привяжите email и пароль для безопасного доступа")
                            .font(.system(size: 15))
                            .foregroundStyle(PetCareTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 16)

                    // Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(PetCareTheme.muted)
                            TextField("ваша@почта.com", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(14)
                                .background(PetCareTheme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Пароль")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(PetCareTheme.muted)
                            SecureField("Минимум 6 символов", text: $password)
                                .padding(14)
                                .background(PetCareTheme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Подтверждение")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(PetCareTheme.muted)
                            SecureField("Повторите пароль", text: $confirmPassword)
                                .padding(14)
                                .background(PetCareTheme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12).stroke(
                                        !confirmPassword.isEmpty && password != confirmPassword ? Color.red : Color.clear
                                    )
                                )

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("Пароли не совпадают")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 16)

                    // Buttons
                    VStack(spacing: 12) {
                        PetCarePrimaryButton(
                            title: viewModel.isLoading ? "Отправляем..." : "Продолжить"
                        ) {
                            Task {
                                await viewModel.linkEmail(email: email, password: password)
                            }
                        }
                        .disabled(!isFormValid || viewModel.isLoading)
                        .opacity(isFormValid ? 1 : 0.6)

                        Button {
                            viewModel.showEmailLinking = false
                        } label: {
                            Text("Пропустить")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(PetCareTheme.primary)
                        }
                    }

                    Spacer()
                }
                .padding(24)
            }
            .background(PetCareTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    EmailLinkingPromptView()
        .environmentObject(AuthViewModel(
            apiClient: HTTPAPIClient(authManager: AuthManager.shared),
            authManager: AuthManager.shared,
            deviceManager: DeviceManager()
        ))
}
```

- [ ] **Step 2: Commit**

```bash
git add Petio-ios/Petio/Features/Auth/EmailLinkingPromptView.swift
git commit -m "feat: add EmailLinkingPromptView for email linking form"
```

---

## Task 7: EmailVerificationView — ввод кода из письма

**Files:**
- Create: `Petio-ios/Petio/Features/Auth/EmailVerificationView.swift`

- [ ] **Step 1: Create EmailVerificationView**

```swift
import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @State private var code = ""
    @State private var canResend = false
    @State private var resendTimer: Timer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(PetCareTheme.primary)

                        Text("Подтвердите email")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(PetCareTheme.primary)

                        if let email = viewModel.currentEmail {
                            Text("Мы отправили код подтверждения на \(email)")
                                .font(.system(size: 15))
                                .foregroundStyle(PetCareTheme.muted)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 16)

                    // Code input
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(PetCareTheme.inputBackground)

                            HStack(spacing: 8) {
                                ForEach(0..<6, id: \.self) { index in
                                    VStack(spacing: 4) {
                                        Text(index < code.count ? String(code[code.index(code.startIndex, offsetBy: index)]) : "")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(PetCareTheme.primary)

                                        Rectangle()
                                            .fill(PetCareTheme.border)
                                            .frame(height: 2)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(16)

                            TextField("000000", text: $code)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .opacity(0.1)
                        }
                        .frame(height: 80)
                        .onChange(of: code) { newValue in
                            code = String(newValue.prefix(6))
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 16)

                    // Buttons
                    VStack(spacing: 12) {
                        PetCarePrimaryButton(
                            title: viewModel.isLoading ? "Проверяем..." : "Подтвердить"
                        ) {
                            Task {
                                await viewModel.verifyEmail(code: code)
                            }
                        }
                        .disabled(code.count != 6 || viewModel.isLoading)
                        .opacity(code.count == 6 ? 1 : 0.6)

                        Button {
                            canResend = false
                            startResendTimer()
                        } label: {
                            if canResend {
                                Text("Отправить код заново")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(PetCareTheme.primary)
                            } else {
                                Text("Отправить код заново через 30 сек")
                                    .font(.system(size: 15))
                                    .foregroundColor(PetCareTheme.muted)
                            }
                        }
                        .disabled(!canResend)
                    }

                    Spacer()
                }
                .padding(24)
            }
            .background(PetCareTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                startResendTimer()
            }
            .onDisappear {
                resendTimer?.invalidate()
            }
        }
    }

    private func startResendTimer() {
        var secondsLeft = 30
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            secondsLeft -= 1
            if secondsLeft <= 0 {
                canResend = true
                resendTimer?.invalidate()
            }
        }
    }
}

#Preview {
    EmailVerificationView()
        .environmentObject(AuthViewModel(
            apiClient: HTTPAPIClient(authManager: AuthManager.shared),
            authManager: AuthManager.shared,
            deviceManager: DeviceManager()
        ))
}
```

- [ ] **Step 2: Commit**

```bash
git add Petio-ios/Petio/Features/Auth/EmailVerificationView.swift
git commit -m "feat: add EmailVerificationView for code verification"
```

---

## Task 8: Обновить AppContainer и ContentView для новых auth flows

**Files:**
- Modify: `Petio-ios/Petio/AppContainer.swift`
- Modify: `Petio-ios/Petio/ContentView.swift`

- [ ] **Step 1: Update AppContainer to initialize AuthViewModel with DeviceManager**

In AppContainer, add DeviceManager initialization and pass to AuthViewModel

- [ ] **Step 2: Update ContentView to show new auth screens**

Update ContentView to show DeviceLoginView when not authenticated, EmailLinkingPromptView when isNew, EmailVerificationView when email linking is in progress

- [ ] **Step 3: Commit**

```bash
git add Petio-ios/Petio/AppContainer.swift \
        Petio-ios/Petio/ContentView.swift
git commit -m "chore: integrate new auth views into app flow"
```

---

## Task 9: Full integration test and verification

- [ ] **Step 1: Build app**

```bash
xcodebuild build -scheme Petio -configuration Debug
```

Expected: **BUILD SUCCESSFUL**

- [ ] **Step 2: Run all existing tests to verify no regressions**

```bash
xcodebuild test -scheme Petio
```

Expected: **ALL TESTS PASS**

- [ ] **Step 3: Manual verification in simulator**

- Launch app
- Should see DeviceLoginView with loader
- Should transition to main screen or EmailLinkingPromptView
- Test email linking flow if applicable

- [ ] **Step 4: Final commit**

```bash
git log --oneline -10
```

Verify all commits are present
