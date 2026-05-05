import Foundation
#if canImport(Security)
import Security
#endif

final class KeychainStore {
    static let shared = KeychainStore()

    private let service = "NodeGetMonitor.Token"

    private init() {}

    func saveToken(_ token: String, for serverID: UUID) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw KeychainStoreError.emptyToken
        }

        #if canImport(Security)
        let data = Data(trimmed.utf8)
        let account = serverID.uuidString

        try? deleteToken(for: serverID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }
        #else
        UserDefaults.standard.set(trimmed, forKey: fallbackKey(for: serverID))
        #endif
    }

    func token(for serverID: UUID) -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
        #else
        return UserDefaults.standard.string(forKey: fallbackKey(for: serverID))
        #endif
    }

    func deleteToken(for serverID: UUID) throws {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID.uuidString
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unhandledStatus(status)
        }
        #else
        UserDefaults.standard.removeObject(forKey: fallbackKey(for: serverID))
        #endif
    }

    private func fallbackKey(for serverID: UUID) -> String {
        "NodeGetMonitor.Token.\(serverID.uuidString)"
    }
}

enum KeychainStoreError: Error, LocalizedError {
    case emptyToken
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyToken:
            return "Token 不能为空。"
        case .unhandledStatus(let status):
            return "Keychain 操作失败：\(status)"
        }
    }
}
