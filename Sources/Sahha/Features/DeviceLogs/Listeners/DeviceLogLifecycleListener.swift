import Foundation

final class DeviceLogLifecycleListener: LifecycleListener {
    private let sensorStore: SensorStoreProtocol
    private let deviceInfoBuilder: DeviceInfoBuilderProtocol
    private let dataLogPipeline: DataLogPipelineProtocol

    init(
        sensorStore: SensorStoreProtocol,
        deviceInfoBuilder: DeviceInfoBuilderProtocol,
        dataLogPipeline: DataLogPipelineProtocol
    ) {
        self.sensorStore = sensorStore
        self.deviceInfoBuilder = deviceInfoBuilder
        self.dataLogPipeline = dataLogPipeline
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        let log: DataLog?
        switch event {
        case .app_locked, .app_unlocked:
            log = await createDeviceLockLog(for: event)
        default:
            log = await createAppLifecycleLog(for: event)
        }

        if let log {
//            await dataLogPipeline.ingest(log)
        }
    }

    private func createAppLifecycleLog(for event: LifecycleEvent) async -> DataLog? {
        let deviceInfo = await deviceInfoBuilder.build()
        return DataLog(
            logType: .device,
            dataType: event.rawValue,
            value: 0,
            unit: "",
            source: deviceInfo.appId,
            recordingMethod: .automatic,
            deviceType: deviceInfo.deviceType,
            startDate: Date(),
            endDate: Date()
        )
    }

    private func createDeviceLockLog(for event: LifecycleEvent) async -> DataLog? {
        guard await sensorStore.hasSensor(.device_lock) else { return nil }
        let deviceInfo = await deviceInfoBuilder.build()
        return DataLog(
            logType: .device,
            dataType: SahhaSensor.device_lock.rawValue,
            value: event == .app_locked ? 1 : 0,
            unit: "",
            source: deviceInfo.appId,
            recordingMethod: .automatic,
            deviceType: deviceInfo.deviceType,
            startDate: Date(),
            endDate: Date()
        )
    }
}
