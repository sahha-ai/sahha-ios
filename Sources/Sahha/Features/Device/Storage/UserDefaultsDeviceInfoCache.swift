import Foundation

final actor UserDefaultsDeviceInfoCache: DeviceInfoCaching {
    private let storage: UserDefaultsStoring
    private let key = StorageKeys.UserDefaults.deviceInfoStateKey
    private let logger: ErrorLogger
    
    private var state: DeviceInfoCacheState?
    
    init(storage: UserDefaultsStoring = UserDefaultsStorage(), logger: ErrorLogger) {
        self.storage = storage
        self.logger = logger
    }

    func set(_ info: DeviceInformation) async {
        let hash = info.safeSha256Hash()
        let newState = DeviceInfoCacheState(hash: hash, lastFetch: Date())
        self.state = newState
        do {
            try await storage.setCodable(newState, forKey: key)
        } catch {
            logger.sdkError("Failed to save device info cache state", error: error)
        }
    }

    func isValid(ttl: TimeInterval) -> Bool {
        guard let state else { return false }
        return Date().timeIntervalSince(state.lastFetch) < ttl
    }

    func needsSync(with info: DeviceInformation) async -> Bool {
        guard let state else { return true }
        return state.hash != info.safeSha256Hash()
    }
}
