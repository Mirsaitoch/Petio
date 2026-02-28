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
            let token = try await authRequest(path: "/auth/login", body: ["email": email, "password": password])
            UserDefaults.standard.set(email, forKey: "petio_session_email")
            authManager.saveToken(token)
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    func register(email: String, password: String, username: String) async {
        isLoading = true
        errorMessage = nil
        let finalUsername = username.trimmingCharacters(in: .whitespaces).isEmpty
            ? Self.generateZooUsername()
            : username
        do {
            let token = try await authRequest(
                path: "/auth/register",
                body: ["email": email, "password": password, "username": finalUsername]
            )
            UserDefaults.standard.set(email, forKey: "petio_session_email")
            UserDefaults.standard.set(finalUsername, forKey: "petio_session_username")
            authManager.saveToken(token)
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    // MARK: - Private

    static func generateZooUsername() -> String {
        let animals = ["cat", "dog", "fox", "owl", "bear", "wolf", "deer", "crow", "frog", "hawk", "puma", "lynx"]
        let animal = animals.randomElement() ?? "pet"
        let number = Int.random(in: 10000...99999)
        return "\(animal)-\(number)"
    }

    private func authRequest(path: String, body: [String: String]) async throws -> String {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
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
