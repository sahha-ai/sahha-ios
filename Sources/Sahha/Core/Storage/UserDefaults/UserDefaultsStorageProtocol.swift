import Foundation

protocol UserDefaultsStorageProtocol: Sendable {
    func set(_ value: Any?, forKey key: String)
    func get(forKey: String) -> Any?
    func removeObject(forKey key: String)
    func allKeys() -> [String]

    // Typed accessors are protocol requirements so injected conformers intercept
    // them; extension-only members would statically bind to the defaults below,
    // which is how test doubles used to be silently bypassed.
    func data(forKey key: String) -> Data?
    func date(forKey key: String) -> Date?
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
    func double(forKey key: String) -> Double
    func float(forKey key: String) -> Float
    func array(forKey key: String) -> [Any]?
    func dictionary(forKey key: String) -> [String: Any]?
}

extension UserDefaultsStorageProtocol {
    // Defaults route through the primitive get/set, so conformers only implement
    // the four primitives. `UserDefaults` coerces where these casts do not (e.g.
    // NSNumber → String); `UserDefaultsStorage` overrides those natively.
    func data(forKey key: String) -> Data? {
        get(forKey: key) as? Data
    }
    func date(forKey key: String) -> Date? {
        get(forKey: key) as? Date
    }
    func string(forKey key: String) -> String? {
        get(forKey: key) as? String
    }
    func bool(forKey key: String) -> Bool {
        get(forKey: key) as? Bool ?? false
    }
    func integer(forKey key: String) -> Int {
        get(forKey: key) as? Int ?? 0
    }
    func double(forKey key: String) -> Double {
        get(forKey: key) as? Double ?? 0
    }
    func float(forKey key: String) -> Float {
        get(forKey: key) as? Float ?? 0
    }
    func array(forKey key: String) -> [Any]? {
        get(forKey: key) as? [Any]
    }
    func dictionary(forKey key: String) -> [String: Any]? {
        get(forKey: key) as? [String: Any]
    }

    func setObject<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        set(data, forKey: key)
    }
    func object<T: Codable>(forKey key: String) throws -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func allKeys(where predicate: (String) -> Bool) -> [String] {
        allKeys().filter(predicate)
    }
}
