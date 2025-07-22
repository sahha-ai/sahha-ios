import Foundation

final actor DemographicCache {
    private let store: KeyValueStore
    private let ttl: TimeInterval
    private let timestampKey = StorageKeys.demographicCacheTimestamp
    private let hashKey = StorageKeys.demographicCacheHash
    private var demographic: SahhaDemographic?

    init(store: KeyValueStore = UserDefaultsStore(), ttl: TimeInterval = .minutes(30)) {
        self.store = store
        self.ttl = ttl
    }

    func load() async -> SahhaDemographic? {
        guard let demo = demographic,
            let timestamp: Date = await store.get(timestampKey),
            Date().timeIntervalSince(timestamp) < ttl
        else {
            demographic = nil
            return nil
        }

        return demo
    }

    func save(_ demographic: SahhaDemographic) async {
        self.demographic = demographic
        await store.set(Date(), forKey: timestampKey)
        if let hash = try? demographic.sha256Hash() {
            await store.set(hash, forKey: hashKey)
        }
    }

    func shouldUpdate(_ demographic: SahhaDemographic) async -> Bool {
        guard let oldHash: String = await store.get(hashKey),
            let newHash = try? demographic.sha256Hash()
        else { return true }
        return oldHash != newHash
    }

    func clear() async {
        demographic = nil
        await store.remove(timestampKey)
        await store.remove(hashKey)
    }
}
