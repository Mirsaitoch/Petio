import Foundation
import Security

final class DeviceManager {
    private let keychainKey = "com.petio.app.device_id"

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
            kSecAttrGeneric as String: keychainKey.data(using: .utf8) ?? Data()
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
            kSecAttrGeneric as String: keychainKey.data(using: .utf8) ?? Data(),
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
            kSecAttrGeneric as String: keychainKey.data(using: .utf8) ?? Data()
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "DeviceManager", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to delete device_id from Keychain"])
        }
    }
}
