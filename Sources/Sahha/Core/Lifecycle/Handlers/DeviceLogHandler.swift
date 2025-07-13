import Foundation

final class DeviceLogHandler: LifecycleHandler {
    private let sensorStore: SensorStore
    private let deviceInfo: DeviceInformation
    private let processor: DataLogProcessor
    private let tokenManager: TokenManager

    init(sensorStore: SensorStore, deviceInfo: DeviceInformation, processor: DataLogProcessor, tokenManager: TokenManager) {
        self.sensorStore = sensorStore
        self.deviceInfo = deviceInfo
        self.processor = processor
        self.tokenManager = tokenManager
    }

    func handleLifecycleEvent(event: LifecycleEvent) async {
        guard await tokenManager.getProfileToken() != nil else { return }
        
        let now = Date()
    
        var dataType: String = event.appEvent
        var value: Double = 0.0

        if event == .lock || event == .unlock {
            let enabledSensors = await sensorStore.getSensors()
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

        await processor.enqueue([dataLog])
    }
}
