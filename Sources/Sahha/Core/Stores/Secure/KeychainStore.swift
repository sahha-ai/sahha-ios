import Foundation
import Security

enum KeychainError: LocalizedError {
    case itemAdd(OSStatus)
    case itemCopy(OSStatus)
    case itemDelete(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemAdd(let status): "Failed to add item to Keychain (status \(status))."
        case .itemCopy(let status): "Failed to read item from Keychain (status \(status))."
        case .itemDelete(let status): "Failed to delete item from Keychain (status \(status))."
        }
    }
}

final actor KeychainStore: SecureStore {
    func set<T: Codable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: SDKConfig.prefix,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.itemAdd(status)
        }
    }

    func get<T: Codable>(_ key: String) throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrService as String: SDKConfig.prefix,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.itemCopy(status)
        }
    }

    func remove(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: SDKConfig.prefix,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.itemDelete(status)
        }
    }
}
