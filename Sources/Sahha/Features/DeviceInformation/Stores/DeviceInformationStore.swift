import Foundation

protocol DeviceInformationStore: Actor {
    func syncIfNeeded() async
    func forceSync() async
}

final actor DeviceInformationStoreImpl: DeviceInformationStore {
    private let userDefaults: UserDefaults
    private let logger: Logger
    private let deviceInfo: DeviceInformation
    private let service: DeviceInformationService

    private let hashKey = Constants.UserDefaultsKeys.DeviceInformation.hash

    private var hash: String?

    init(userDefaults: UserDefaults = .standard, logger: Logger, deviceInfo: DeviceInformation, service: DeviceInformationService) {
        self.userDefaults = userDefaults
        self.logger = logger
        self.deviceInfo = deviceInfo
        self.service = service
        self.hash = userDefaults.string(forKey: hashKey)
    }
    
    func syncIfNeeded() async {
        let newHash = hashInfo(deviceInfo)
        
        guard shouldSync(newHash: newHash) else { return }
        
        await forceSync()
    }
    
    func forceSync() async {
        do {
            try await service.updateDeviceInformation(deviceInfo)
            if let newHash = hashInfo(deviceInfo) {
                userDefaults.set(newHash, forKey: hashKey)
                hash = newHash
            }
            logger.info("Device information synced successfully")
        } catch {
            logger.error("Failed to sync device info: \(error.localizedDescription)")
        }
    }

    private func shouldSync(newHash: String?) -> Bool {
        newHash == nil || hash != newHash
    }

    private func hashInfo(_ info: DeviceInformation) -> String? {
        do {
            return try info.sha256Hash()
        } catch {
            logger.error("Failed to hash device info: \(error.localizedDescription)")
            return nil
        }
    }
}
