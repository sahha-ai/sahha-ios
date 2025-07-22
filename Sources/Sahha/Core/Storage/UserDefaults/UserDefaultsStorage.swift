import Foundation

 final actor UserDefaultsStorage: UserDefaultsStoring {
    private let defaults: UserDefaults

    /// - Parameter suiteName: Optional suite name for shared defaults
    init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap(UserDefaults.init) ?? .standard
    }

    func set(_ value: Data, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func get(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func delete(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
     
     func allKeys() -> [String] {
         Array(defaults.dictionaryRepresentation().keys)
     }
}
