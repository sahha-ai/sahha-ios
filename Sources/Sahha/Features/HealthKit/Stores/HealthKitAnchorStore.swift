import HealthKit

actor HealthKitAnchorStore: HealthKitAnchorStoreProtocol, Disposable {
    private let prefix = StorageKeys.UserDefaults.hkAnchorPrefix
    private let storage: UserDefaultsStorageProtocol
    
    init(storage: UserDefaultsStorageProtocol) {
        self.storage = storage
    }
    
    func saveAnchor(_ anchor: HKQueryAnchor, forKey key: String) throws {
        let key = prefix + key
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: anchor,
            requiringSecureCoding: true
        )
        storage.set(data, forKey: key)
    }

    func loadAnchor(forKey key: String) throws -> HKQueryAnchor? {
        let key = prefix + key
        guard let data = storage.data(forKey: key) else { return nil }
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = true
        return unarchiver.decodeObject(of: HKQueryAnchor.self, forKey: NSKeyedArchiveRootObjectKey)
    }

    func dispose() async {
        let keys = storage.allKeys { $0.hasPrefix(self.prefix) }
        keys.forEach(storage.removeObject)
    }
}
