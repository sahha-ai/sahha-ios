import Foundation

final class UserDefaultsStorage: UserDefaultsStorageProtocol {
    func set(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    func get(forKey key: String) -> Any? {
        UserDefaults.standard.value(forKey: key)
    }

    func removeObject(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    func allKeys() -> [String] {
        return Array(UserDefaults.standard.dictionaryRepresentation().keys)
    }
}
