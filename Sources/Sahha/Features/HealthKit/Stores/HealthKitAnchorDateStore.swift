import HealthKit

actor HealthKitAnchorDateStore: HealthKitAnchorDateStoreProtocol, Disposable {
    private let prefix = StorageKeys.UserDefaults.hkAnchorDatePrefix
    private let storage: UserDefaultsStorageProtocol
    
    init(storage: UserDefaultsStorageProtocol) {
        self.storage = storage
    }
    
    func saveAnchorDate(_ date: Date, forKey key: String) {
        let key = prefix + key
        storage.set(date, forKey: key)
    }
    
    func loadAnchorDate(forKey key: String) -> Date? {
        let key = prefix + key
        return storage.date(forKey: key)
    }

    func dispose() async {
        let keys = storage.allKeys { $0.hasPrefix(self.prefix) }
        keys.forEach(storage.removeObject)
    }
}
