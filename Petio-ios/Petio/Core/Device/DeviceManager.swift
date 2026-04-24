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
