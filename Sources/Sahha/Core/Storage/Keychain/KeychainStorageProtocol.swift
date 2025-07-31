import Foundation

protocol KeychainStorageProtocol: Sendable {
    func set(_ value: Data, forKey key: String) throws
    func set<T: Codable>(_ value: T, forKey key: String) throws
    func get(forKey: String) throws -> Data?
    func get<T: Codable>(forKey key: String) throws -> T?
    func removeObject(forKey key: String) throws
}
