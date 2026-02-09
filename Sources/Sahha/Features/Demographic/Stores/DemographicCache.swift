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
    
    private var cachedDemographic: CachedDemographic?
    
    init(
        key: String = StorageKeys.Keychain.demographic,
        storage: KeychainStorageProtocol,
        ttl: TimeInterval = .hours(1),
        logger: ErrorLoggerProtocol
    ) {
        self.key = key
        self.storage = storage
        self.ttl = ttl
        self.logger = logger
        
        do {
            self.cachedDemographic = try storage.object(forKey: key)
        } catch {
            // Non-critical: silent failure
        }
    }
    
    private func isCacheValid(_ lastSync: Date) -> Bool {
        lastSync.addingTimeInterval(ttl) >= Date()
    }
    
    func getDemographic() async -> SahhaDemographic? {
        if let cached = cachedDemographic, isCacheValid(cached.lastSync) {
            return cached.demographic
        }
        do {
            if let cached: CachedDemographic = try storage.object(forKey: key),
               isCacheValid(cached.lastSync) {
                cachedDemographic = cached
                return cached.demographic
            } else {
                cachedDemographic = nil
                return nil
            }
        } catch {
            // Non-critical: silent failure
            return nil
        }
    }
    
    func cacheDemographic(_ demographic: SahhaDemographic) {
        let value = CachedDemographic(demographic: demographic, lastSync: Date())
        cachedDemographic = value
        do {
            try storage.setObject(value, forKey: key)
        } catch {
            // Non-critical: silent failure
        }
    }
    
    /// Checks if the given demographic matches the cached value and the TTL has not expired
    func needsUpdate(comparedTo demographic: SahhaDemographic) -> Bool {
        if let cached = cachedDemographic {
            return cached.demographic != demographic || !isCacheValid(cached.lastSync)
        }
        do {
            if let cached: CachedDemographic = try storage.object(forKey: key) {
                cachedDemographic = cached
                return cached.demographic != demographic || !isCacheValid(cached.lastSync)
            } else {
                return true
            }
        } catch {
            // Non-critical: silent failure
            return true
        }
    }
    
    func dispose() async {
        cachedDemographic = nil
        do {
            try storage.removeObject(forKey: key)
        } catch {
            // Non-critical: silent failure
        }
    }
}
