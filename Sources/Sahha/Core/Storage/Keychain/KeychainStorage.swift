import Foundation

final actor KeychainStorage: KeychainStoring {
    private let service: String

    /// - Parameter service: The Keychain 'service' attribute (defaults to your SDK bundle ID)
    init(service: String = StorageKeys.Keychain.service) {
        self.service = service
    }

    func set(_ value: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        // Add new
        var item = query
        item[kSecValueData as String] = value
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StorageError.unhandledError(status: status)
        }
    }

    func get(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw StorageError.unexpectedData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw StorageError.unhandledError(status: status)
        }
    }

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.unhandledError(status: status)
        }
    }
}
