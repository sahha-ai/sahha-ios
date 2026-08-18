import Foundation

private struct CachedDeviceInfo: Codable {
    let hash: String
    let lastSync: Date
}

actor DeviceInfoSyncCache: DeviceInfoSyncCacheProtocol, Disposable {
    private let key: String
    private let storage: UserDefaultsStorageProtocol
    private let ttl: TimeInterval
    private let logger: ErrorLoggerProtocol
    /// Latched by `dispose()` (container teardown, e.g. deauthentication). A sync
    /// flight that resolves after teardown must not write the hash back — the next
    /// session's `needsSync` would then skip the new profile's first device-info sync.
    private var disposed = false

    init(
        key: String = StorageKeys.UserDefaults.deviceInfo,
        storage: UserDefaultsStorageProtocol,
        ttl: TimeInterval = .hours(1),
        logger: ErrorLoggerProtocol
    ) {
        self.key = key
        self.storage = storage
        self.ttl = ttl
        self.logger = logger
    }

    func cacheDeviceInfo(_ deviceInfo: DeviceInfo) {
        guard !disposed else { return }
        do {
            let hash = try deviceInfo.sha256Hash()
            let value = CachedDeviceInfo(hash: hash, lastSync: Date())
            try storage.setObject(value, forKey: key)
        } catch {
        }
    }

    func dispose() {
        disposed = true
        storage.removeObject(forKey: key)
    }

    func needsSync(comparedTo deviceInfo: DeviceInfo) -> Bool {
        do {
            guard let cached: CachedDeviceInfo = try storage.object(forKey: key) else { return true }
            
            let newHash = try deviceInfo.sha256Hash()
            let cacheExpired = cached.lastSync.addingTimeInterval(ttl) < Date()
            
            return cached.hash != newHash || cacheExpired
        } catch {
            return true
        }
    }
}
