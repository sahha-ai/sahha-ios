import Foundation

protocol DemographicStore: Actor, Disposable {
    func getDemographic() async throws -> SahhaDemographic?
    func updateDemographic(_ demographic: SahhaDemographic) async throws
}

final actor DemographicStoreImpl: DemographicStore {
    private let userDefaults: UserDefaults
    private let logger: Logger
    private let service: DemographicService

    private let cacheTTL: TimeInterval
    private let lastFetchKey = Constants.UserDefaultsKeys.Demographic.lastFetch
    private let hashKey = Constants.UserDefaultsKeys.Demographic.hash

    private var demographic: SahhaDemographic?
    private var hash: String?
    private var lastFetch: Date?

    init(userDefaults: UserDefaults = .standard, logger: Logger, service: DemographicService, cacheTTL: TimeInterval = .minutes(30)) {
        self.userDefaults = userDefaults
        self.logger = logger
        self.service = service
        self.cacheTTL = cacheTTL
        self.hash = userDefaults.string(forKey: hashKey)
        self.lastFetch = userDefaults.object(forKey: lastFetchKey) as? Date
    }

    func getDemographic() async throws -> SahhaDemographic? {
        if let cached = demographic, isCacheFresh() {
            return cached
        }

        let demographic = try await service.getDemographic()
        updateCache(with: demographic)
        return demographic
    }

    func updateDemographic(_ demographic: SahhaDemographic) async throws {
        let newHash = hashDemographic(demographic)
        guard shouldUpdate(newHash: newHash) else { return }

        try await service.updateDemographic(demographic)
        updateCache(with: demographic, hash: newHash)
    }
    
    func dispose() async {
        self.demographic = nil
        self.lastFetch = nil
        self.hash = nil
        userDefaults.removeObject(forKey: hashKey)
        userDefaults.removeObject(forKey: lastFetchKey)
    }
    
    private func shouldUpdate(newHash: String?) -> Bool {
        newHash == nil || newHash != hash
    }

    private func isCacheFresh() -> Bool {
        guard let last = lastFetch else { return false }
        return Date().timeIntervalSince(last) < cacheTTL
    }

    private func updateCache(with demographic: SahhaDemographic, hash newHash: String? = nil) {
        self.demographic = demographic
        self.lastFetch = Date()
        userDefaults.set(self.lastFetch, forKey: lastFetchKey)

        if let newHash = newHash ?? hashDemographic(demographic) {
            self.hash = newHash
            userDefaults.set(newHash, forKey: hashKey)
        }
    }

    private func hashDemographic(_ demographic: SahhaDemographic) -> String? {
        do {
            return try demographic.sha256Hash()
        } catch {
            logger.error("Failed to hash demographic: \(error.localizedDescription)")
            return nil
        }
    }
}
