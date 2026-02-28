//
//  AuthViewModel.swift
//  Petio
//
//  Handles login and registration. Makes direct HTTP calls to /auth endpoints (no JWT needed).
//

import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authManager: AuthManager
    private let baseURL = "http://localhost:8080/v1"

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let token = try await authRequest(path: "/auth/login", email: email, password: password)
            authManager.saveToken(token)
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    func register(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let token = try await authRequest(path: "/auth/register", email: email, password: password)
            authManager.saveToken(token)
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    // MARK: - Private

    private func authRequest(path: String, email: String, password: String) async throws -> String {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidURL }
        guard (200..<300).contains(http.statusCode) else { throw APIError.server(http.statusCode) }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let token = json["token"] else {
            throw APIError.decoding(URLError(.cannotDecodeRawData))
        }
        return token
    }

    private func describe(_ error: Error) -> String {
        guard let apiError = error as? APIError else {
            return "Произошла ошибка. Попробуйте ещё раз."
        }
        switch apiError {
        case .server(401): return "Неверный email или пароль."
        case .server(409): return "Пользователь с таким email уже существует."
        case .server(let code): return "Ошибка сервера: \(code)."
        case .network: return "Нет подключения к интернету."
        default: return "Произошла ошибка. Попробуйте ещё раз."
        }
    }
}
