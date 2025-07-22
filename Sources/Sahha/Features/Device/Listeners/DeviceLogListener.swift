import Foundation

final actor DeviceLogListener: LifecycleListener {
    private let collector: DeviceInfoCollector
    private let sensorStore: SensorStore
    private let processor: DataLogProcessor

    init(collector: DeviceInfoCollector, sensorStore: SensorStore, processor: DataLogProcessor) {
        self.collector = collector
        self.sensorStore = sensorStore
        self.processor = processor
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        if event == .app_locked || event == .app_unlocked {
            let enabled = await sensorStore.getEnabledSensors()
            guard enabled.contains(.device_lock) else { return }
        }

        let timestamp = Date()
        let deviceInfo = await collector.collect()
        let (dataType, value) = metrics(for: event)

        let log = DataLog(
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

        do {
            try await processor.enqueue(log, for: SahhaSensor.device_lock.rawValue)
        } catch {
            print("Failed to enqueue log: \(error)")
        }
    }

    private func metrics(for event: LifecycleEvent) -> (String, Double) {
        switch event {
        case .app_locked: return (SahhaSensor.device_lock.rawValue, 1)
        case .app_unlocked: return (SahhaSensor.device_lock.rawValue, 0)
        default: return (event.rawValue, 0)
        }
    }
}
