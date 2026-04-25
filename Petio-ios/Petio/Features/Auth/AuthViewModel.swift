//
//  AuthViewModel.swift
//  Petio
//
//  Device-based authentication with optional email linking.
//

import Foundation
import Petio

struct AccountInfo: Codable {
    let userId: String
    let email: String?
    let isCurrentAccount: Bool
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deviceAccounts: [AccountInfo] = []
    @Published var currentEmail: String?
    @Published var showEmailLinking = false

    private let authManager: AuthManager
    private let deviceManager = DeviceManager.shared
    private let baseURL = "http://158.160.235.224:8080/v1"

    init(authManager: AuthManager) {
        self.authManager = authManager
        self.isAuthenticated = authManager.getToken() != nil
    }

    // MARK: - Device Login

    func deviceLogin() async {
        isLoading = true
        errorMessage = nil
        do {
            let deviceID = try await deviceManager.getDeviceID()
            let response = try await deviceLoginRequest(deviceID: deviceID)
            authManager.saveToken(response.token)
            authManager.saveRefreshToken(response.refreshToken)
            updateAuth(true)
            if response.isNew {
                showEmailLinking = true
            }
        } catch {
            errorMessage = describe(error)
            updateAuth(false)
        }
        isLoading = false
    }

    // MARK: - Account Management

    func listDeviceAccounts() async throws -> [AccountInfo] {
        let deviceID = try await deviceManager.getDeviceID()
        let accounts = try await listAccountsRequest(deviceID: deviceID)
        await MainActor.run { self.deviceAccounts = accounts }
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
            updateAuth(true)
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
            showEmailLinking = false
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    // MARK: - Private API Requests

    private func deviceLoginRequest(deviceID: String) async throws -> DeviceLoginResponse {
        struct Request: Encodable {
            let device_id: String
        }
        struct Response: Decodable {
            let token: String
            let refreshToken: String
            let userId: String
            let isNew: Bool
        }
        let response: Response = try await apiRequest(
            path: "/auth/device",
            method: "POST",
            body: Request(device_id: deviceID)
        )
        return DeviceLoginResponse(
            token: response.token,
            refreshToken: response.refreshToken,
            userId: response.userId,
            isNew: response.isNew
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

    private func switchAccountRequest(deviceID: String, userId: String) async throws -> SwitchAccountResponse {
        struct Request: Encodable {
            let device_id: String
            let user_id: String
        }
        struct Response: Decodable {
            let token: String
            let refreshToken: String
        }
        let response: Response = try await apiRequest(
            path: "/auth/device/switch",
            method: "POST",
            body: Request(device_id: deviceID, user_id: userId)
        )
        return SwitchAccountResponse(token: response.token, refreshToken: response.refreshToken)
    }

    private func linkEmailRequest(email: String, password: String) async throws {
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
    }

    private func verifyEmailRequest(code: String) async throws {
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

    private func updateAuth(_ authenticated: Bool) {
        isAuthenticated = authenticated
    }
}

// MARK: - Response Models

private struct DeviceLoginResponse {
    let token: String
    let refreshToken: String
    let userId: String
    let isNew: Bool
}

private struct SwitchAccountResponse {
    let token: String
    let refreshToken: String
}
