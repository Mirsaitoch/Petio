//
//  AuthManager.swift
//  Petio
//
//  JWT token storage in iOS Keychain. Single source of truth for auth state.
//

import Foundation
import Security

final class AuthManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool

    private let keychainService = "com.petio.app"
    private let keychainAccount = "authToken"

    init() {
        isAuthenticated = AuthManager.readFromKeychain(service: "com.petio.app", account: "authToken") != nil
    }

    /// Save token to Keychain and mark as authenticated.
    func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
        updateAuth(true)
    }

    /// Read token from Keychain. Thread-safe (Keychain reads are safe from any thread).
    func getToken() -> String? {
        loadFromKeychain()
    }

    /// Remove token from Keychain and mark as unauthenticated.
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        updateAuth(false)
    }

    // MARK: - Private

    private func loadFromKeychain() -> String? {
        AuthManager.readFromKeychain(service: keychainService, account: keychainAccount)
    }

    private static func readFromKeychain(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    /// Update @Published property on main thread (safe to call from any thread).
    private func updateAuth(_ value: Bool) {
        if Thread.isMainThread {
            isAuthenticated = value
        } else {
            DispatchQueue.main.async { self.isAuthenticated = value }
        }
    }
}
