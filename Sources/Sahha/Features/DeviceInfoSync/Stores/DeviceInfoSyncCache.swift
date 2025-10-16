import Foundation

private struct CachedDeviceInfo: Codable {
    let hash: String
    let lastSync: Date
}

actor DeviceInfoSyncCache: DeviceInfoSyncCacheProtocol {
    private let key: String
    private let storage: UserDefaultsStorageProtocol
    private let ttl: TimeInterval
    private let logger: ErrorLoggerProtocol

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
        do {
            let hash = try deviceInfo.sha256Hash()
            let value = CachedDeviceInfo(hash: hash, lastSync: Date())
            try storage.setObject(value, forKey: key)
        } catch {
            logger.postError(error)
        }
    }

    func needsSync(comparedTo deviceInfo: DeviceInfo) -> Bool {
        do {
            guard let cached: CachedDeviceInfo = try storage.object(forKey: key) else { return true }
            
            let newHash = try deviceInfo.sha256Hash()
            let cacheExpired = cached.lastSync.addingTimeInterval(ttl) < Date()
            
            return cached.hash != newHash || cacheExpired
        } catch {
            logger.postError(error)
            return true
        }
    }
}
