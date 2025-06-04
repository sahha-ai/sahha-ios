import Foundation
import Security

final class KeychainStorage<T: Codable> {
    private let account: String
    private let service: String
    
    init(account: String, service: String = Bundle.main.bundleIdentifier ?? "ai.sahha.ios.keychain.storage") {
        self.account = account
        self.service = service
    }
    
    func set(_ object: T) -> Bool {
        guard let data = try? JSONEncoder().encode(object) else { return false }
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service,
            kSecValueData: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func get() -> T? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }

        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    func delete() -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
