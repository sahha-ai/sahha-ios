import Foundation

protocol KeychainStoring: Actor {
    /// Store raw data in the keychain under a given key
    func set(_ value: Data, forKey key: String) throws
    /// Retrieve raw data from the keychain for a given key
    func get(forKey key: String) throws -> Data?
    /// Delete data from the keychain for a given key
    func delete(forKey key: String) throws
}

extension KeychainStoring {
    /// Store a Codable value in the keychain
    func setCodable<T: Codable>(_ value: T, forKey key: String) throws {
        do {
            let data = try JSONEncoder().encode(value)
            try set(data, forKey: key)
        } catch {
            throw StorageError.encodingError(error)
        }
    }

    /// Retrieve a Codable value from the keychain
    func getCodable<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        do {
            guard let data = try get(forKey: key) else {
                return nil
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as StorageError {
            throw error
        } catch {
            throw StorageError.decodingError(error)
        }
    }
}
