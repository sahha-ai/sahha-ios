import Foundation

protocol KeychainStorageProtocol: Sendable {
    func set(_ value: Data, forKey key: String) throws
    func get(forKey: String) throws -> Data?
    func removeObject(forKey key: String) throws
}

extension KeychainStorageProtocol {
    func setObject<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        try set(data, forKey: key)
    }
    func object<T: Codable>(forKey key: String) throws -> T? {
        guard let data = try get(forKey: key) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
