import HealthKit

final actor UserDefaultsHKAnchorStorage: HKAnchorStoring {
    private let defaults: UserDefaultsStoring
    private let prefix = StorageKeys.UserDefaults.hkAnchorPrefix

    init(defaults: UserDefaultsStoring = UserDefaultsStorage()) {
        self.defaults = defaults
    }

    func saveAnchor(_ anchor: HKQueryAnchor, for key: String) async throws {
        let key = prefix + key
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: anchor,
            requiringSecureCoding: true
        )
        await defaults.set(data, forKey: key)
    }

    func loadAnchor(for key: String) async throws -> HKQueryAnchor? {
        let key = prefix + key
        guard let data = await defaults.get(forKey: key) else { return nil }
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = true
        return unarchiver.decodeObject(of: HKQueryAnchor.self, forKey: NSKeyedArchiveRootObjectKey)
    }

    func deleteAnchor(for key: String) async {
        let key = prefix + key
        await defaults.delete(forKey: key)
    }

    func deleteAllAnchors() async {
        let allKeys = await defaults.allKeys()
        let anchorKeys = allKeys.filter { $0.hasPrefix(prefix) }
        for key in anchorKeys {
            await defaults.delete(forKey: key)
        }
    }
    
    func dispose() async {
        await deleteAllAnchors()
    }
}
