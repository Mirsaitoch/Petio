//
//  AuthViewModel.swift
//  Petio
//
//  Device-based authentication with optional email linking,
//  email+password login, and password recovery.
//

import Foundation

struct AccountInfo: Codable {
    let userId: String
    let email: String?
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deviceAccounts: [AccountInfo] = []
    @Published var currentEmail: String?
    @Published var showEmailLinking = false
    @Published var isVerifyingEmail = false
    @Published var passwordRecoverySheet: PasswordRecoverySheet?
    @Published var didLogin = false

    enum PasswordRecoverySheet: Identifiable {
        case forgotPassword
        case resetPassword

        var id: Self { self }
    }

    let authManager: AuthManager
    private let deviceManager = DeviceManager.shared
    private let baseURL = "http://158.160.235.224/v1"

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    var isAuthenticated: Bool {
        authManager.isAuthenticated
    }

    // MARK: - Device Login

    func deviceLogin() async {
        isLoading = true
        errorMessage = nil
        do {
            let deviceID = try await deviceManager.getDeviceID()
            print("[DEVICE_LOGIN] got deviceID=\(deviceID)")
            let response = try await deviceLoginRequest(deviceID: deviceID)
            print("[DEVICE_LOGIN] response: token=\(response.token.prefix(10))..., isNew=\(response.isNew)")
            authManager.saveToken(response.token)
            authManager.saveRefreshToken(response.refreshToken)

            // Always authenticate immediately — user can use the app right away.
            // Email linking is optional and available from profile settings.
            authManager.setAuthenticated(true)
        } catch {
            print("[DEVICE_LOGIN] error: \(error)")
            errorMessage = describe(error)
            authManager.setAuthenticated(false)
        }
        isLoading = false
    }

    /// Skip email linking — authenticate with anonymous account.
    func skipEmailLinking() {
        showEmailLinking = false
        authManager.setAuthenticated(true)
    }

    // MARK: - Register (device + link email)

    /// Creates anonymous device account, then initiates email linking.
    func register(email: String, password: String, username: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let deviceID = try await deviceManager.getDeviceID()
            let response = try await deviceLoginRequest(deviceID: deviceID)
            authManager.saveToken(response.token)
            authManager.saveRefreshToken(response.refreshToken)
            authManager.setAuthenticated(false)

            // Immediately start email linking
            try await linkEmailRequest(email: email, password: password)
            currentEmail = email
            showEmailLinking = true
            isVerifyingEmail = true
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    // MARK: - Email + Password Login

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await emailLoginRequest(email: email, password: password)
            authManager.saveToken(response.token)
            authManager.saveRefreshToken(response.refreshToken)
            authManager.setAuthenticated(true)
            didLogin = true
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    // MARK: - Account Management

    func listDeviceAccounts() async throws -> [AccountInfo] {
        let deviceID = try await deviceManager.getDeviceID()
        let accounts = try await listAccountsRequest(deviceID: deviceID)
        deviceAccounts = accounts
        return accounts
    }

    func switchAccount(userId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let deviceID = try await deviceManager.getDeviceID()
            let response = try await switchAccountRequest(deviceID: deviceID, userId: userId)
            authManager.saveToken(response.token)
            authManager.saveRefreshToken(response.refreshToken)
            authManager.setAuthenticated(true)
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    // MARK: - Email Linking

    func linkEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await linkEmailRequest(email: email, password: password)
            currentEmail = email
            showEmailLinking = true
            isVerifyingEmail = true
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    func verifyEmail(code: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await verifyEmailRequest(code: code)
            isVerifyingEmail = false
            showEmailLinking = false
            authManager.setAuthenticated(true)
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    // MARK: - Password Recovery

    func forgotPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await forgotPasswordRequest(email: email)
            currentEmail = email
            passwordRecoverySheet = .resetPassword
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    func resetPassword(email: String, code: String, newPassword: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await resetPasswordRequest(email: email, code: code, newPassword: newPassword)
            passwordRecoverySheet = nil
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    // MARK: - Logout

    func logout() {
        authManager.deleteToken()
        showEmailLinking = false
        isVerifyingEmail = false
        passwordRecoverySheet = nil
        currentEmail = nil
    }

    // MARK: - Private API Requests

    private func deviceLoginRequest(deviceID: String) async throws -> TokenPairWithUser {
        struct Request: Encodable { let device_id: String }
        return try await apiRequest(
            path: "/auth/device",
            method: "POST",
            body: Request(device_id: deviceID)
        )
    }

    private func emailLoginRequest(email: String, password: String) async throws -> TokenPair {
        struct Request: Encodable {
            let email: String
            let password: String
        }
        return try await apiRequest(
            path: "/auth/login",
            method: "POST",
            body: Request(email: email, password: password),
            includeAuth: false
        )
    }

    private func listAccountsRequest(deviceID: String) async throws -> [AccountInfo] {
        let url = baseURL + "/auth/device/accounts?device_id=\(deviceID)"
        guard let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let finalURL = URL(string: encodedURL) else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: finalURL)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.network(URLError(.badServerResponse)) }
        guard (200..<300).contains(http.statusCode) else { throw APIError.server(http.statusCode) }

        return try JSONDecoder().decode([AccountInfo].self, from: data)
    }

    private func switchAccountRequest(deviceID: String, userId: String) async throws -> TokenPair {
        struct Request: Encodable {
            let device_id: String
            let user_id: String
        }
        return try await apiRequest(
            path: "/auth/device/switch",
            method: "POST",
            body: Request(device_id: deviceID, user_id: userId)
        )
    }

    private func linkEmailRequest(email: String, password: String) async throws {
        struct Request: Encodable {
            let email: String
            let password: String
        }
        struct Response: Decodable { let status: String }
        let _: Response = try await apiRequest(
            path: "/auth/link-email",
            method: "POST",
            body: Request(email: email, password: password)
        )
    }

    private func verifyEmailRequest(code: String) async throws {
        struct Request: Encodable { let code: String }
        struct Response: Decodable { let status: String }
        let _: Response = try await apiRequest(
            path: "/auth/verify-email",
            method: "POST",
            body: Request(code: code)
        )
    }

    private func forgotPasswordRequest(email: String) async throws {
        struct Request: Encodable { let email: String }
        struct Response: Decodable { let status: String }
        let _: Response = try await apiRequest(
            path: "/auth/forgot-password",
            method: "POST",
            body: Request(email: email),
            includeAuth: false
        )
    }

    private func resetPasswordRequest(email: String, code: String, newPassword: String) async throws {
        struct Request: Encodable {
            let email: String
            let code: String
            let new_password: String
        }
        struct Response: Decodable { let status: String }
        let _: Response = try await apiRequest(
            path: "/auth/reset-password",
            method: "POST",
            body: Request(email: email, code: code, new_password: newPassword),
            includeAuth: false
        )
    }

    // MARK: - Generic API Request Helper

    private func apiRequest<T: Decodable, B: Encodable>(
        path: String,
        method: String = "GET",
        body: B? = nil,
        includeAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if includeAuth, let token = authManager.getToken() {
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

    // MARK: - Utility

    static func generateZooUsername() -> String {
        let animals = ["cat", "dog", "fox", "owl", "bear", "wolf", "deer", "crow", "frog", "hawk", "puma", "lynx"]
        let animal = animals.randomElement() ?? "pet"
        let number = Int.random(in: 10000...99999)
        return "\(animal)-\(number)"
    }
}

// MARK: - Response Models

private struct TokenPair: Decodable {
    let token: String
    let refreshToken: String
}

private struct TokenPairWithUser: Decodable {
    let token: String
    let refreshToken: String
    let userId: String
    let isNew: Bool
}
