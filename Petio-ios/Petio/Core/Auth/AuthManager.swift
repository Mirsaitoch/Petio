//
//  AuthManager.swift
//  Petio
//
//  JWT token storage in iOS Keychain. Single source of truth for auth state.
//

import Foundation
import Security

final class AuthManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false

    private let keychainTokenKey = "com.petio.app.token"
    private let keychainRefreshTokenKey = "com.petio.app.refreshToken"

    init() {
        let hasToken = AuthManager.readFromKeychain(keychainKey: "com.petio.app.token") != nil
        self.isAuthenticated = hasToken
    }

    /// Save token to Keychain and mark as authenticated.
    func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        guard let genericData = keychainTokenKey.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrGeneric as String: genericData
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        let status = SecItemAdd(attrs as CFDictionary, nil)
        if status == errSecSuccess || status == errSecDuplicateItem {
            updateAuth(true)
        }
    }

    /// Read token from Keychain. Thread-safe (Keychain reads are safe from any thread).
    func getToken() -> String? {
        AuthManager.readFromKeychain(keychainKey: keychainTokenKey)
    }

    /// Save refresh token to Keychain.
    func saveRefreshToken(_ refreshToken: String) {
        guard let data = refreshToken.data(using: .utf8) else { return }
        guard let genericData = keychainRefreshTokenKey.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrGeneric as String: genericData
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        let _ = SecItemAdd(attrs as CFDictionary, nil)
    }

    /// Read refresh token from Keychain. Thread-safe.
    func getRefreshToken() -> String? {
        AuthManager.readFromKeychain(keychainKey: keychainRefreshTokenKey)
    }

    /// Remove both token and refresh token from Keychain and mark as unauthenticated.
    func deleteToken() {
        // Delete access token
        if let tokenGenericData = keychainTokenKey.data(using: .utf8) {
            let tokenQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrGeneric as String: tokenGenericData
            ]
            SecItemDelete(tokenQuery as CFDictionary)
        }

        // Delete refresh token
        if let refreshTokenGenericData = keychainRefreshTokenKey.data(using: .utf8) {
            let refreshTokenQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrGeneric as String: refreshTokenGenericData
            ]
            SecItemDelete(refreshTokenQuery as CFDictionary)
        }

        updateAuth(false)
    }

    // MARK: - Private

    private static func readFromKeychain(keychainKey: String) -> String? {
        guard let genericData = keychainKey.data(using: .utf8) else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrGeneric as String: genericData,
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

extension AuthManager {
    static let shared = AuthManager()
}
