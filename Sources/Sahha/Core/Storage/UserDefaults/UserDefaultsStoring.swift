import Foundation

protocol UserDefaultsStoring: Actor {
    /// Store raw data under a given key
    func set(_ value: Data, forKey key: String)
    /// Retrieve raw data for a given key
    func get(forKey key: String) -> Data?
    /// Delete data for a given key
    func delete(forKey key: String)
    /// Returns all keys in userDefaults
    func allKeys() -> [String]
}

extension UserDefaultsStoring {
    /// Store a Codable value
    func setCodable<T: Codable>(_ value: T, forKey key: String) throws {
        do {
            let data = try JSONEncoder().encode(value)
            set(data, forKey: key)
        } catch {
            throw StorageError.encodingError(error)
        }
    }

    /// Retrieve a Codable value
    func getCodable<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        do {
            guard let data = get(forKey: key) else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw StorageError.decodingError(error)
        }
    }
}
