import Foundation

extension LifecycleEvent {
    func toDataLog(deviceInfo: DeviceInformation) -> DataLog {
        let timestamp = Date()
        let (dataType, value) = metrics()
        
        return DataLog(
            logType: .device,
            dataType: dataType,
            value: value,
            unit: "",
            source: deviceInfo.appId,
            recordingMethod: .automatic,
            deviceType: deviceInfo.deviceType,
            startDate: timestamp,
            endDate: timestamp
        )
    }
    
    private func metrics() -> (String, Double) {
        switch self {
        case .app_locked: return (SahhaSensor.device_lock.rawValue, 1)
        case .app_unlocked: return (SahhaSensor.device_lock.rawValue, 0)
        default: return (self.rawValue, 0)
        }
    }
}
