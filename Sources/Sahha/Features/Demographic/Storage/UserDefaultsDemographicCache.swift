import Foundation

final actor UserDefaultsDemographicCache: DemographicCaching {
    private let storage: UserDefaultsStoring
    private let key = StorageKeys.UserDefaults.demographicStateKey
    private let logger: ErrorLogger

    private var state: DemographicCacheState?
    private var demographic: SahhaDemographic?

    init(storage: UserDefaultsStoring = UserDefaultsStorage(), logger:ErrorLogger) {
        self.storage = storage
        self.logger = logger
    }

    func get() -> SahhaDemographic? {
        demographic
    }

    func set(_ demographic: SahhaDemographic) async {
        self.demographic = demographic
        let hash = demographic.safeSha256Hash()
        let newState = DemographicCacheState(hash: hash, lastFetch: Date())
        self.state = newState
        do {
            try await storage.setCodable(newState, forKey: key)
        } catch {
            logger.sdkError("Failed to save demographic cache state", error: error)
        }
    }

    func isValid(ttl: TimeInterval) -> Bool {
        guard let state else { return false }
        return Date().timeIntervalSince(state.lastFetch) < ttl
    }

    func needsSync(with demographic: SahhaDemographic) async -> Bool {
        guard let state else { return true }
        return state.hash != demographic.safeSha256Hash()
    }
    
    func clear() async {
        state = nil
        demographic = nil
        await storage.delete(forKey: key)
    }
    
    func dispose() async {
        await clear()
    }
}
