import Foundation

struct ArchivedUserDefaultsStorage<T: NSObject & NSSecureCoding> {
    private let key: String
    private let userDefaults: UserDefaults

    init(key: String, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.userDefaults = userDefaults
    }

    func set(_ object: T) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true)
            userDefaults.set(data, forKey: key)
        } catch {
            print("ArchivedUserDefaultsStorage: Failed to encode object for key '\(key)': \(error)")
        }
    }

    func get() -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data)
    }

    func delete() {
        userDefaults.removeObject(forKey: key)
    }
}
