import Foundation
import OSLog
import Security

enum KeychainStoreError: Error, Equatable {
    case saveFailed(OSStatus)
}

final class KeychainStore: @unchecked Sendable {
    static let shared = KeychainStore()

    private let logger = Logger(subsystem: "ResumeBuilder", category: "KeychainStore")

    private init() {}

    func save(_ value: Data, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        var insert = query
        insert[kSecValueData as String] = value
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(insert as CFDictionary, nil)
        if status == errSecSuccess { return }

        if status == errSecDuplicateItem {
            let updates: [String: Any] = [
                kSecValueData as String: value,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
            guard updateStatus == errSecSuccess else {
                logger.error("Keychain update failed status=\(updateStatus)")
                throw KeychainStoreError.saveFailed(updateStatus)
            }
            return
        }

        logger.error("Keychain save failed status=\(status)")
        throw KeychainStoreError.saveFailed(status)
    }

    func read(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func accessibilityAttribute(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let accessible = attributes[kSecAttrAccessible as String] as? String
        else { return nil }
        return accessible
    }

    func remove(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
