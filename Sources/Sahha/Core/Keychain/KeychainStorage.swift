import Foundation
import Security

final actor KeychainStorage<T: Codable & Sendable>: KeychainProtocol {
    private let service: String = Constants.Keychain.service
    private let account: String

    init(key: String) {
        self.account = key
    }

    func save(_ value: T) async throws {
        guard let data = try? JSONEncoder().encode(value) else {
            throw KeychainError.encodingFailed
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service,
            kSecValueData: data,
        ]

        // Delete existing item to avoid duplicates
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed("Keychain error (status: \(status))")
        }
    }

    func retrieve() async throws -> T? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.itemNotFound
        }

        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw KeychainError.decodingFailed
        }

        return decoded
    }

    func delete() async throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed("Keychain error (status: \(status))")
        }
    }
}
