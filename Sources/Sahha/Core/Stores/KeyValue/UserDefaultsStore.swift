import Foundation

final actor UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func set<T: Codable>(_ value: T, forKey key: String) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            assertionFailure("Failed to encode and store value for key \(key): \(error)")
        }
    }

    func get<T: Codable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            assertionFailure("Failed to decode value for key \(key): \(error)")
            return nil
        }
    }

    func remove(_ key: String) {
        defaults.removeObject(forKey: key)
    }
}
