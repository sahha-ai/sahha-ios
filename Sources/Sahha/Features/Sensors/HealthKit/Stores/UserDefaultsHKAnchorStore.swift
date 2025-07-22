import Foundation
import HealthKit

final actor UserDefaultsHKAnchorStore: HKAnchorStore {
    private let defaults: UserDefaults
    private let prefix = StorageKeys.hkAnchorPrefix

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func loadAnchor(for key: String) throws -> HKQueryAnchor? {
        let key = prefix + key
        guard let data = defaults.data(forKey: key) else { return nil }
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = true
        return unarchiver.decodeObject(of: HKQueryAnchor.self, forKey: NSKeyedArchiveRootObjectKey)
    }

    func saveAnchor(_ anchor: HKQueryAnchor, for key: String) throws {
        let key = prefix + key
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: anchor,
            requiringSecureCoding: true
        )
        defaults.set(data, forKey: key)
    }
    
    func dispose() async {
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(prefix) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
