import Foundation

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

final class AppEventManager: AppEventManagerProtocol {
    private let logger: LoggerProtocol
    private let lifecycleObserver: LifecycleObserverProtocol
    private let sensorsManager: SensorsManagerProtocol
    private let dataLogProcessor: any DataLogProcessorProtocol
    private let deviceInfoManager: DeviceInformationManagerProtocol

    init(
        logger: LoggerProtocol,
        lifecycleObserver: LifecycleObserverProtocol,
        sensorsManager: SensorsManagerProtocol,
        dataLogProcessor: any DataLogProcessorProtocol,
        deviceInfoManager: DeviceInformationManagerProtocol
    ) {
        self.logger = logger
        self.lifecycleObserver = lifecycleObserver
        self.sensorsManager = sensorsManager
        self.dataLogProcessor = dataLogProcessor
        self.deviceInfoManager = deviceInfoManager
    }

    func start() async {
        await lifecycleObserver.addHandler(self, for: Set(LifecycleEvent.allCases))
    }

    func handleLifecycleEvent(event: LifecycleEvent) async {
        let now = Date()
        let deviceInfo = await deviceInfoManager.getDeviceInformation()

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
            source: deviceInfo.appId,
            recordingMethod: .automatic,
            deviceType: deviceInfo.deviceType,
            startDate: now,
            endDate: now,
            additionalProperties: nil
        )

        do {
            try await dataLogProcessor.process([dataLog])
        } catch {
            logger.error("Failed to process DataLog for event \(event): \(error)")
        }
    }

    func dispose() async {
        await lifecycleObserver.removeHandler(self)
    }
}
