import CryptoKit
import Foundation
import UIKit

final actor DeviceInformationManager: DeviceInformationManagerProtocol, LifecycleHandler {
    private let logger: LoggerProtocol
    private let userDefaults: UserDefaults
    private let framework: SahhaFramework
    private let deviceInfoService: DeviceInformationServiceProtocol
    private let lifecycleObserver: LifecycleObserverProtocol
    private let cacheTTL: TimeInterval

    private let lastSyncKey = Constants.UserDefaultsKeys.deviceInfoLastSync
    private let deviceIdKey =  Constants.UserDefaultsKeys.deviceInfoDeviceId
    private let hashKey =  Constants.UserDefaultsKeys.deviceInfoHash

    private var cachedInfo: DeviceInformation?
    private var cachedHash: String?
    private var lastSyncTimestamp: Date?
    private var syncTask: Task<Void, Never>?

    init(
        logger: LoggerProtocol,
        userDefaults: UserDefaults = .standard,
        cacheTTL: TimeInterval = .hours(1),
        framework: SahhaFramework,
        deviceInfoService: DeviceInformationServiceProtocol,
        lifecycleObserver: LifecycleObserverProtocol
    ) {
        self.logger = logger
        self.userDefaults = userDefaults
        self.cacheTTL = cacheTTL
        self.framework = framework
        self.deviceInfoService = deviceInfoService
        self.lifecycleObserver = lifecycleObserver
        self.cachedHash = userDefaults.string(forKey: hashKey)
        self.lastSyncTimestamp = userDefaults.object(forKey: lastSyncKey) as? Date
        Task { await collectDeviceInformation() }
    }

    func getDeviceInformation() async -> DeviceInformation {
        guard let cached = cachedInfo else {
            return await collectDeviceInformation()
        }
        return cached
    }

    private func isSyncStale() -> Bool {
        guard let lastSyncTimestamp = lastSyncTimestamp else {
            return true  // Sync if no previous sync exists
        }
        return Date().timeIntervalSince(lastSyncTimestamp) >= cacheTTL
    }

    func requiresSync() async -> Bool {
        if isSyncStale() {
            return true  // Sync if the last sync is too old
        }
        let current = await getDeviceInformation()
        do {
            let hash = try current.sha256Hash()
            return cachedHash == nil || cachedHash != hash
        } catch {
            logger.error("Failed to hash device information: \(error.localizedDescription)")
            return true
        }
    }
    
    func start() async {
        await lifecycleObserver.addHandler(self, for: [.didBecomeActive])
    }

    func handleLifecycleEvent(event: LifecycleEvent) async {
        await syncDeviceInformation()
    }
    
    func dispose() async throws {
        await lifecycleObserver.removeHandler(self)
    }

    private func syncDeviceInformation() async {
        if let task = syncTask {
            logger.warning("Device information sync already in progress, awaiting completion...")
            await task.value
            return
        }

        guard await self.requiresSync() else {
            logger.info("Skipping device information sync, information unchanged")
            return
        }

        let task = Task {
            defer { syncTask = nil }
            let info = await self.getDeviceInformation()
            do {
                try await self.deviceInfoService.updateDeviceInformation(info)
                cachedInfo = info
                do {
                    cachedHash = try info.sha256Hash()
                    userDefaults.set(cachedHash, forKey: hashKey)
                } catch {
                    logger.error("Failed to hash device information: \(error.localizedDescription)")
                }
                lastSyncTimestamp = Date()
                userDefaults.set(lastSyncTimestamp, forKey: lastSyncKey)
                logger.info("Updated device information successfully")
            } catch {
                logger.error("Failed to sync device information: \(error.localizedDescription)")
            }
        }

        syncTask = task
        await task.value
    }

    private func collectDeviceInformation() async -> DeviceInformation {
        let device = await UIDevice.current
        let bundle = Bundle.main
        let deviceId = await getDeviceId()

        var systemInfo = utsname()
        let deviceModel =
            uname(&systemInfo) == 0
            ? withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 256) {
                    String(cString: $0)
                }
            } : "unknown"

        let info = await DeviceInformation(
            sdkId: framework.rawValue,
            sdkVersion: Constants.sdkVersion,
            appId: bundle.bundleIdentifier ?? "unknown",
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            deviceId: deviceId,
            deviceType: device.model,
            deviceModel: deviceModel,
            system: device.systemName,
            systemVersion: device.systemVersion,
            timeZone: Date().utcOffset
        )
        cachedInfo = info
        return info
    }

    private func getDeviceId() async -> String {
        if let storedDeviceId = userDefaults.string(forKey: deviceIdKey) {
            return storedDeviceId
        }
        let newDeviceId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        userDefaults.set(newDeviceId, forKey: deviceIdKey)
        return newDeviceId
    }
}
