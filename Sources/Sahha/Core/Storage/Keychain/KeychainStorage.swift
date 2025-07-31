import Foundation

final class KeychainStorage: KeychainStorageProtocol {
    private let service: String

    init(service: String = StorageKeys.Keychain.service) {
        self.service = service
    }

    func set(_ value: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        // Add new
        var item = query
        item[kSecValueData as String] = value
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            let nsError = NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [
                    NSLocalizedDescriptionKey: message
                ]
            )
            throw SahhaError(message: "Failed to store data in keychain: \(key)", error: nsError)
        }
    }

    func set<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        try set(data, forKey: key)
    }

    func get(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw SahhaError(message: "Keychain item for key '\(key)' found but data is missing or not a Data object.")
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            let nsError = NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [
                    NSLocalizedDescriptionKey: message
                ]
            )
            throw SahhaError(message: "Failed to retrieve data from keychain: \(key)", error: nsError)
        }
    }

    func get<T: Codable>(forKey key: String) throws -> T? {
        guard let data = try get(forKey: key) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func removeObject(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            let nsError = NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [
                    NSLocalizedDescriptionKey: message
                ]
            )
            throw SahhaError(message: "Failed to delete data from keychain: \(key)", error: nsError)
        }
    }
}
