import Foundation

struct UserDefaultsStorage<T: Codable>: StorageProtocol {
    private let key: String
    private let userDefaults: UserDefaults
    
    init(key: String, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.userDefaults = userDefaults
    }
    
    func get() -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    @discardableResult
    func set(_ object: T) -> Bool {
        guard let data = try? JSONEncoder().encode(object) else { return false }
        userDefaults.set(data, forKey: key)
        return true
    }
    
    @discardableResult
    func delete() -> Bool {
        userDefaults.removeObject(forKey: key)
        return true
    }
}
