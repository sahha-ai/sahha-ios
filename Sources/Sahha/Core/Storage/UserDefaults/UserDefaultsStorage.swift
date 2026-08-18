import Foundation

final class UserDefaultsStorage: UserDefaultsStorageProtocol {
    func set(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    // object(forKey:), not value(forKey:) — the KVC path diverges for keys
    // NSUserDefaults treats specially (e.g. "@"-prefixed keys raise).
    func get(forKey key: String) -> Any? {
        UserDefaults.standard.object(forKey: key)
    }

    func removeObject(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func allKeys() -> [String] {
        return Array(UserDefaults.standard.dictionaryRepresentation().keys)
    }

    // UserDefaults implements these natively with coercion (e.g. NSNumber → String,
    // string → Bool); explicit overrides keep production semantics identical to the
    // pre-seam extension. data/date have no native coercion, so the protocol
    // defaults already match.
    func string(forKey key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
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
}
