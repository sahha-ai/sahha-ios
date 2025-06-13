import Foundation
import Security

protocol KeychainStorageProtocol<T> {
    associatedtype T: Codable
    
    func get() -> T?
    func set(_ value: T) throws
    func delete() throws
}

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case itemAddFailed(OSStatus)
    case itemDeleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode data for Keychain storage."
        case .itemAddFailed(let status):
            return "Failed to add item to Keychain (status: \(status))."
        case .itemDeleteFailed(let status):
            return "Failed to delete item from Keychain (status: \(status))."
        }
    }
}

struct KeychainStorage<T: Codable>: KeychainStorageProtocol {
    private let account: String
    private let service: String = "ai.sahha.ios"
    
    init(account: String) {
        self.account = account
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
        
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            return nil
        }
        
        return decoded
    }
    
    func set(_ value: T) throws {
        guard let data = try? JSONEncoder().encode(value) else {
            throw KeychainError.encodingFailed
        }
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service,
            kSecValueData: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.itemAddFailed(status)
        }
    }
    
    func delete() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecAttrService: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.itemDeleteFailed(status)
        }
    }
}
