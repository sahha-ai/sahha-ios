import Foundation

protocol DemographicManagerProtocol: Actor, DisposableAsync {
    func getDemographic() async throws -> SahhaDemographic
    func updateDemographic(_ demographic: SahhaDemographic) async throws
}

final actor DemographicManager: DemographicManagerProtocol {
    private let logger: LoggerProtocol
    private let userDefaults: UserDefaults
    private let demographicService: DemographicServiceProtocol
    private let cacheTTL: TimeInterval

    private let lastFetchKey = Constants.UserDefaultsKeys.demographiclastFetch
    private let hashKey = Constants.UserDefaultsKeys.demographicHash

    private var cachedDemographic: SahhaDemographic?
    private var cachedHash: String?
    private var lastFetchTimestamp: Date?

    init(
        logger: LoggerProtocol,
        userDefaults: UserDefaults = .standard,
        cacheTTL: TimeInterval = .minutes(15),
        demographicService: DemographicServiceProtocol
    ) {
        self.logger = logger
        self.userDefaults = userDefaults
        self.cacheTTL = cacheTTL
        self.demographicService = demographicService
        self.cachedHash = userDefaults.string(forKey: hashKey)
        self.lastFetchTimestamp = userDefaults.object(forKey: lastFetchKey) as? Date
    }

    func getDemographic() async throws -> SahhaDemographic {
        if let cached = cachedDemographic, !isCacheStale() {
            return cached
        }
        let demographic = try await demographicService.getDemographic()
        updateCache(demographic: demographic)
        return demographic
    }

    private func shouldUpdateDemographic(_ demographic: SahhaDemographic) -> Bool {
        do {
            let hash = try demographic.sha256Hash()
            return hash != cachedHash
        } catch {
            logger.error("Failed to hash demographic: \(error.localizedDescription)", file: #file, function: #function)
            return true
        }
    }

    func updateDemographic(_ demographic: SahhaDemographic) async throws {
        guard shouldUpdateDemographic(demographic) else {
            return
        }
        try await demographicService.updateDemographic(demographic)
        updateCache(demographic: demographic)
    }
    
    func dispose() async throws {
        cachedDemographic = nil
        cachedHash = nil
        lastFetchTimestamp = nil
        userDefaults.removeObject(forKey: hashKey)
        userDefaults.removeObject(forKey: lastFetchKey)
        
    }

    private func isCacheStale() -> Bool {
        guard let lastFetchTimestamp = lastFetchTimestamp else {
            return true
        }
        return Date().timeIntervalSince(lastFetchTimestamp) >= cacheTTL
    }

    private func updateCache(demographic: SahhaDemographic) {
        cachedDemographic = demographic
        do {
            cachedHash = try demographic.sha256Hash()
            userDefaults.set(cachedHash, forKey: hashKey)
        } catch {
            logger.error("Failed to hash demographic: \(error.localizedDescription)", file: #file, function: #function)
        }
        lastFetchTimestamp = Date()
        userDefaults.set(lastFetchTimestamp, forKey: lastFetchKey)
    }
}
