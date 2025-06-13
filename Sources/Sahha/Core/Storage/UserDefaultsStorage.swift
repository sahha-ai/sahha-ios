import Foundation

protocol UserDefaultsStorageProtocol<T> {
    associatedtype T: Codable
    
    func get() -> T?
    func set(_ value: T)
    func delete()
}

struct UserDefaultsStorage<T: Codable>: UserDefaultsStorageProtocol {
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
    
    func set(_ object: T) {
        guard let data = try? JSONEncoder().encode(object) else { return }
        userDefaults.set(data, forKey: key)
    }
    
    func delete() {
        userDefaults.removeObject(forKey: key)
    }
}
