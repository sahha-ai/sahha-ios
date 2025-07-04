import CryptoKit
import Foundation
import UIKit

extension LifecycleEvent {
    fileprivate var appEvent: String {
        switch self {
        case .start: return "app_start"
        case .didBecomeActive: return "app_resume"
        case .pause: return "app_pause"
        case .foreground: return "app_foreground"
        case .background: return "app_background"
        case .close: return "app_close"
        case .unlock: return "device_unlock"
        case .lock: return "device_lock"
        }
    }
}

protocol DeviceManagerProtocol: Actor, DisposableAsync {
    func syncDeviceInformation() async
    func trackLifecycleEvents() async
}

final actor DeviceManager: DeviceManagerProtocol, LifecycleHandler {
    private let logger: LoggerProtocol
    private let userDefaults: UserDefaults
    private let deviceInformation: DeviceInformation
    private let deviceService: DeviceServiceProtocol
    private let lifecycleObserver: LifecycleObserverProtocol
    private let sensorsManager: SensorsManagerProtocol
    private let dataLogProcessor: DataLogProcessorProtocol

    private let hashKey =  Constants.UserDefaultsKeys.deviceInfoHash

    private var cachedHash: String?
    private var syncTask: Task<Void, Never>?

    init(
        logger: LoggerProtocol,
        userDefaults: UserDefaults = .standard,
        deviceInformation: DeviceInformation,
        deviceService: DeviceServiceProtocol,
        lifecycleObserver: LifecycleObserverProtocol,
        sensorsManager: SensorsManagerProtocol,
        dataLogProcessor: DataLogProcessorProtocol,
    ) {
        self.logger = logger
        self.userDefaults = userDefaults
        self.deviceInformation = deviceInformation
        self.deviceService = deviceService
        self.lifecycleObserver = lifecycleObserver
        self.sensorsManager = sensorsManager
        self.dataLogProcessor = dataLogProcessor
        self.cachedHash = userDefaults.string(forKey: hashKey)
    }

    private func requiresSync() async -> Bool {
        do {
            let hash = try deviceInformation.sha256Hash()
            return cachedHash == nil || cachedHash != hash
        } catch {
            logger.error("Failed to hash device information: \(error.localizedDescription)", file: #file, function: #function)
            return true
        }
    }

    func syncDeviceInformation() async {
        if let task = syncTask {
            logger.info("Device information sync already in progress, awaiting completion...")
            await task.value
            return
        }

        guard await self.requiresSync() else {
            logger.info("Skipping device information sync, information unchanged")
            return
        }

        let task = Task {
            defer { syncTask = nil }
            do {
                try await self.deviceService.updateDeviceInformation(deviceInformation)
                do {
                    cachedHash = try deviceInformation.sha256Hash()
                    userDefaults.set(cachedHash, forKey: hashKey)
                } catch {
                    logger.error("Failed to hash device information: \(error.localizedDescription)", file: #file, function: #function)
                }
                logger.info("Updated device information successfully")
            } catch {
                logger.error("Failed to sync device information: \(error.localizedDescription)", file: #file, function: #function)
            }
        }

        syncTask = task
        await task.value
    }
    
    func trackLifecycleEvents() async {
        await lifecycleObserver.addHandler(self, for: Set(LifecycleEvent.allCases))
    }
    
    func handleLifecycleEvent(event: LifecycleEvent) async {
        let now = Date()
    
        var dataType: String = event.appEvent
        var value: Double = 0.0

        if event == .lock || event == .unlock {
            let enabledSensors = await sensorsManager.getEnabledSensors()
            if !enabledSensors.contains(.device_lock) {
                return
            }
            dataType = SahhaSensor.device_lock.rawValue
            value = event == .lock ? 1.0 : 0.0
        }

        let dataLog = DataLog(
            parentId: nil,
            logType: .device,
            dataType: dataType,
            value: value,
            unit: "",
            source: deviceInformation.appId,
            recordingMethod: .automatic,
            deviceType: deviceInformation.deviceType,
            startDate: now,
            endDate: now,
            additionalProperties: nil
        )

        await dataLogProcessor.process([dataLog])
    }
    
    func dispose() async throws {
        userDefaults.removeObject(forKey: hashKey)
        await lifecycleObserver.removeHandler(self)
    }
}
