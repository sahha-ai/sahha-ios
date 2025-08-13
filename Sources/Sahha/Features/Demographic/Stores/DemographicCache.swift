import Foundation

private struct CachedDemographic: Codable {
    let demographic: SahhaDemographic
    let lastSync: Date
}

actor DemographicCache: DemographicCacheProtocol {
    private let key: String
    private let storage: KeychainStorageProtocol
    private let ttl: TimeInterval
    private let logger: ErrorLoggerProtocol

    // Keep the full cache object in memory, not just the demographic
    private var cachedDemographic: CachedDemographic?

    init(
        key: String = StorageKeys.UserDefaults.deviceInfo,
        storage: KeychainStorageProtocol,
        ttl: TimeInterval = .hours(1),
        logger: ErrorLoggerProtocol
    ) {
        self.key = key
        self.storage = storage
        self.ttl = ttl
        self.logger = logger
    }

    private func isCacheValid(_ lastSync: Date) -> Bool {
        lastSync.addingTimeInterval(ttl) >= Date()
    }

    func getDemographic() async -> SahhaDemographic? {
        // Prefer in-memory cache if valid
        if let cached = cachedDemographic, isCacheValid(cached.lastSync) {
            return cached.demographic
        }
        // Else load from Keychain
        do {
            guard let cached: CachedDemographic = try storage.object(forKey: key),
                  isCacheValid(cached.lastSync) else {
                cachedDemographic = nil
                return nil
            }
            cachedDemographic = cached
            return cached.demographic
        } catch {
            logger.postError(error)
            return nil
        }
    }

    func cacheDemographic(_ demographic: SahhaDemographic) {
        let value = CachedDemographic(demographic: demographic, lastSync: Date())
        cachedDemographic = value
        do {
            try storage.setObject(value, forKey: key)
        } catch {
            logger.postError(error)
        }
    }

    /// Checks if the given demographic matches the cached value and the TTL has not expired
    func needsUpdate(comparedTo demographic: SahhaDemographic) -> Bool {
        // Prefer in-memory cache if available
        if let cached = cachedDemographic {
            return cached.demographic == demographic && isCacheValid(cached.lastSync)
        }
        do {
            guard let cached: CachedDemographic = try storage.object(forKey: key) else { return false }
            cachedDemographic = cached
            return cached.demographic == demographic && isCacheValid(cached.lastSync)
        } catch {
            logger.postError(error)
            return false
        }
    }

    func dispose() async {
        cachedDemographic = nil
        do {
            try storage.removeObject(forKey: key)
        } catch {
            logger.postError(error)
        }
    }
}
