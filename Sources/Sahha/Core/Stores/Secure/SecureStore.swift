import Foundation
import Security

protocol SecureStore: Actor {
    func set<T: Codable>(_ value: T, forKey key: String) throws
    func get<T: Codable>(_ key: String) throws -> T?
    func remove(_ key: String) throws
}
