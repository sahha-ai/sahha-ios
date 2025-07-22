import Foundation

final actor DeviceInfoCache {
    private let store: KeyValueStore
    private let ttl: TimeInterval
    private let timestampKey = StorageKeys.deviceInfoCacheTimestamp
    private let hashKey = StorageKeys.deviceInfoCacheHash
    private var deviceInfo: DeviceInformation?

    init(store: KeyValueStore = UserDefaultsStore(), ttl: TimeInterval = .hours(1)) {
        self.store = store
        self.ttl = ttl
    }

    func load() async -> DeviceInformation? {
        guard let info = deviceInfo,
            let timestamp: Date = await store.get(timestampKey),
            Date().timeIntervalSince(timestamp) < ttl
        else {
            deviceInfo = nil
            return nil
        }

        return info
    }

    func save(_ info: DeviceInformation) async {
        self.deviceInfo = info
        await store.set(Date(), forKey: timestampKey)
        if let hash = try? info.sha256Hash() {
            await store.set(hash, forKey: hashKey)
        }
    }

    func shouldUpdate(_ info: DeviceInformation) async -> Bool {
        guard let oldHash: String = await store.get(hashKey),
            let newHash = try? info.sha256Hash(),
            let timestamp: Date = await store.get(timestampKey),
            Date().timeIntervalSince(timestamp) < ttl
        else { return true }
        return oldHash != newHash
    }

    func clear() async {
        deviceInfo = nil
        await store.remove(timestampKey)
        await store.remove(hashKey)
    }
}
