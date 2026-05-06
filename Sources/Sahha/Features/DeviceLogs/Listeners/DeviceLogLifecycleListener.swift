import Foundation

final actor DeviceLogLifecycleListener: LifecycleListener, Disposable {
    private let sensorStore: SensorStoreProtocol
    private let deviceInfoBuilder: DeviceInfoBuilderProtocol
    private let profileIdProvider: ProfileIdProviderProtocol
    private let dataLogPipeline: DataLogPipelineProtocol

    private var bufferedLogs: [DataLog] = []
    private(set) var authenticated: Bool = false

    init(
        sensorStore: SensorStoreProtocol,
        deviceInfoBuilder: DeviceInfoBuilderProtocol,
        profileIdProvider: ProfileIdProviderProtocol,
        dataLogPipeline: DataLogPipelineProtocol,
    ) {
        self.sensorStore = sensorStore
        self.deviceInfoBuilder = deviceInfoBuilder
        self.profileIdProvider = profileIdProvider
        self.dataLogPipeline = dataLogPipeline
    }

    func setAuthenticated(_ value: Bool) async {
        authenticated = value
        if value { await flush() }
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        let log: DataLog?
        switch event {
        case .app_locked, .app_unlocked:
            log = await createDeviceLockLog(for: event)
        default:
            log = await createAppLifecycleLog(for: event)
        }

        guard let log else { return }

        if authenticated {
            let profileId = profileIdProvider.profileId()
            let authenticatedLog = DataLog(
                profileId: profileId,
                logType: log.logType,
                dataType: log.dataType,
                value: log.value,
                unit: log.unit,
                source: log.source,
                recordingMethod: log.recordingMethod,
                deviceType: log.deviceType,
                startDate: log.startDate,
                endDate: log.endDate,
                additionalProperties: log.additionalProperties
            )
            await dataLogPipeline.ingest(authenticatedLog)
        } else {
            bufferedLogs.append(log)
        }
    }

    func flush() async {
        let profileId = profileIdProvider.profileId()
        for log in bufferedLogs {
            let regenerated = DataLog(
                profileId: profileId,
                logType: log.logType,
                dataType: log.dataType,
                value: log.value,
                unit: log.unit,
                source: log.source,
                recordingMethod: log.recordingMethod,
                deviceType: log.deviceType,
                startDate: log.startDate,
                endDate: log.endDate,
                additionalProperties: log.additionalProperties
            )
            await dataLogPipeline.ingest(regenerated)
        }
        bufferedLogs.removeAll()
    }

    func dispose() async {
        authenticated = false
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
