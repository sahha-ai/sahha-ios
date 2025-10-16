import Foundation

protocol UserDefaultsStorageProtocol: Sendable {
    func set(_ value: Any?, forKey key: String)
    func get(forKey: String) -> Any?
    func removeObject(forKey key: String)
    func allKeys() -> [String]
}

extension UserDefaultsStorageProtocol {
    func data(forKey key: String) -> Data? {
        UserDefaults.standard.data(forKey: key)
    }
    func setObject<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        UserDefaults.standard.set(data, forKey: key)
    }
    func object<T: Codable>(forKey key: String) throws -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func string(forKey key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }
    func date(forKey key: String) -> Date? {
        UserDefaults.standard.value(forKey: key) as? Date
    }
    func bool(forKey key: String) -> Bool {
        UserDefaults.standard.bool(forKey: key)
    }
    func integer(forKey key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }
    func double(forKey key: String) -> Double {
        UserDefaults.standard.double(forKey: key)
    }
    func float(forKey key: String) -> Float {
        UserDefaults.standard.float(forKey: key)
    }
    func array(forKey key: String) -> [Any]? {
        UserDefaults.standard.array(forKey: key)
    }
    func dictionary(forKey key: String) -> [String: Any]? {
        UserDefaults.standard.dictionary(forKey: key)
    }
    func allKeys(where predicate: (String) -> Bool) -> [String] {
        allKeys().filter(predicate)
    }
}
