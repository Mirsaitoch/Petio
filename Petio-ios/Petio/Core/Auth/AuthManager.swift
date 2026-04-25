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

    private let keychainService = "com.petio.app"
    private let keychainTokenAccount = "token"
    private let keychainRefreshTokenAccount = "refreshToken"

    init() {
        let hasToken = AuthManager.readFromKeychain(service: keychainService, account: keychainTokenAccount) != nil
        self.isAuthenticated = hasToken
    }

    /// Save token to Keychain and mark as authenticated.
    func saveToken(_ token: String) {
        print("[KEYCHAIN] saveToken: starting, token length=\(token.count)")
        saveToKeychain(service: keychainService, account: keychainTokenAccount, value: token)
        updateAuth(true)
    }

    /// Read token from Keychain. Thread-safe (Keychain reads are safe from any thread).
    func getToken() -> String? {
        let token = AuthManager.readFromKeychain(service: keychainService, account: keychainTokenAccount)
        print("[KEYCHAIN] getToken: account='\(keychainTokenAccount)', found=\(token != nil), length=\(token?.count ?? 0)")
        return token
    }

    /// Save refresh token to Keychain.
    func saveRefreshToken(_ refreshToken: String) {
        print("[KEYCHAIN] saveRefreshToken: starting, token length=\(refreshToken.count)")
        saveToKeychain(service: keychainService, account: keychainRefreshTokenAccount, value: refreshToken)
    }

    /// Read refresh token from Keychain. Thread-safe.
    func getRefreshToken() -> String? {
        let token = AuthManager.readFromKeychain(service: keychainService, account: keychainRefreshTokenAccount)
        print("[KEYCHAIN] getRefreshToken: account='\(keychainRefreshTokenAccount)', found=\(token != nil), length=\(token?.count ?? 0)")
        return token
    }

    /// Explicitly set authentication state.
    func setAuthenticated(_ value: Bool) {
        updateAuth(value)
    }

    /// Remove both token and refresh token from Keychain and mark as unauthenticated.
    func deleteToken() {
        deleteFromKeychain(service: keychainService, account: keychainTokenAccount)
        deleteFromKeychain(service: keychainService, account: keychainRefreshTokenAccount)
        updateAuth(false)
    }

    // MARK: - Private

    private func saveToKeychain(service: String, account: String, value: String) {
        guard let data = value.data(using: .utf8) else {
            print("[KEYCHAIN] saveToKeychain: failed to encode to UTF-8")
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // Try to update first
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess {
            print("[KEYCHAIN] saveToKeychain: updated (\(service)/\(account))")
            return
        }

        // If not found, add new
        if updateStatus == errSecItemNotFound {
            var attrs = query
            attrs[kSecValueData as String] = data
            let addStatus = SecItemAdd(attrs as CFDictionary, nil)
            if addStatus == errSecSuccess {
                print("[KEYCHAIN] saveToKeychain: added (\(service)/\(account))")
            } else {
                print("[KEYCHAIN] saveToKeychain: FAILED to add (\(service)/\(account)), status=\(addStatus)")
            }
            return
        }

        print("[KEYCHAIN] saveToKeychain: FAILED (\(service)/\(account)), status=\(updateStatus)")
    }

    private func deleteFromKeychain(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        print("[KEYCHAIN] deleteFromKeychain: deleted (\(service)/\(account))")
    }

    private static func readFromKeychain(service: String, account: String) -> String? {
        print("[KEYCHAIN] readFromKeychain: trying \(service)/\(account)")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            print("[KEYCHAIN] readFromKeychain: not found (status=\(status))")
            return nil
        }
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            print("[KEYCHAIN] readFromKeychain: failed to decode data")
            return nil
        }
        print("[KEYCHAIN] readFromKeychain: success, length=\(value.count)")
        return value
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
