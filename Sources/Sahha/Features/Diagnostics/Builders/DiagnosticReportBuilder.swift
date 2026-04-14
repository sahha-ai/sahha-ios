import Foundation

protocol DiagnosticReportBuilderProtocol: Sendable {
    func buildReport() async -> DiagnosticReport
    func getLatestReport() async -> DiagnosticReport?
}

actor DiagnosticReportBuilder: DiagnosticReportBuilderProtocol {
    private let sensorStore: SensorStoreProtocol
    private let dataLogUploader: DataLogUploaderProtocol
    private let tagUploader: TagUploaderProtocol
    private let circuitBreaker: CircuitBreaker?
    private let networkMonitor: NetworkMonitor
    private let deviceInfoBuilder: DeviceInfoBuilderProtocol
    private let storage: UserDefaultsStorageProtocol

    private let storageKey = "com.sahha.diagnostic_report"

    init(
        sensorStore: SensorStoreProtocol,
        dataLogUploader: DataLogUploaderProtocol,
        tagUploader: TagUploaderProtocol,
        circuitBreaker: CircuitBreaker?,
        networkMonitor: NetworkMonitor,
        deviceInfoBuilder: DeviceInfoBuilderProtocol,
        storage: UserDefaultsStorageProtocol
    ) {
        self.sensorStore = sensorStore
        self.dataLogUploader = dataLogUploader
        self.tagUploader = tagUploader
        self.circuitBreaker = circuitBreaker
        self.networkMonitor = networkMonitor
        self.deviceInfoBuilder = deviceInfoBuilder
        self.storage = storage
    }

    func buildReport() async -> DiagnosticReport {
        let deviceInfo = await deviceInfoBuilder.build()

        let enabledSensors: Set<SahhaSensor> = (try? await sensorStore.getSensors()) ?? []
        let storedStatuses = await sensorStore.getSensorStatuses()
        let sensorStatuses = Self.backfillStatuses(enabled: enabledSensors, statuses: storedStatuses)

        let dataLogQueueStats = await dataLogUploader.getDLQStatistics()
        let tagQueueStats = await tagUploader.getDLQStatistics()

        let cbState: (CircuitState, Int)
        if let circuitBreaker {
            cbState = await circuitBreaker.getState()
        } else {
            cbState = (.closed, 0)
        }

        let networkConnected = await networkMonitor.isConnected

        let report = DiagnosticReport(
            timestamp: Date(),
            sdkVersion: SDK.version,
            deviceModel: deviceInfo.deviceModel,
            system: deviceInfo.system,
            systemVersion: deviceInfo.systemVersion,
            appId: deviceInfo.appId,
            enabledSensors: enabledSensors.map(\.rawValue).sorted(),
            sensorStatuses: Dictionary(
                uniqueKeysWithValues: sensorStatuses.map { ($0.key.rawValue, $0.value.rawValue) }
            ),
            queues: DiagnosticReport.Queues(
                dataLog: queueSnapshot(from: dataLogQueueStats),
                tag: queueSnapshot(from: tagQueueStats)
            ),
            circuitBreakerState: String(describing: cbState.0),
            circuitBreakerFailures: cbState.1,
            isNetworkConnected: networkConnected
        )

        try? storage.setObject(report, forKey: storageKey)
        return report
    }

    func getLatestReport() async -> DiagnosticReport? {
        try? storage.object(forKey: storageKey)
    }

    /// Pure transformation: every sensor in `enabled` gets an entry in the returned map,
    /// backfilled as `.pending` when absent from `statuses`. Existing entries are preserved.
    static func backfillStatuses(
        enabled: Set<SahhaSensor>,
        statuses: [SahhaSensor: SahhaSensorStatus]
    ) -> [SahhaSensor: SahhaSensorStatus] {
        var result = statuses
        for sensor in enabled where result[sensor] == nil {
            result[sensor] = .pending
        }
        return result
    }

    private func queueSnapshot(from stats: PersistenceStatistics) -> DiagnosticReport.QueueSnapshot {
        let oldestAge: TimeInterval?
        if let oldest = stats.oldestTimestamp {
            oldestAge = Date().timeIntervalSince1970 - oldest
        } else {
            oldestAge = nil
        }
        return DiagnosticReport.QueueSnapshot(
            totalBatches: stats.totalBatches,
            totalItems: stats.totalItems,
            failedBatches: stats.failedBatches,
            oldestBatchAge: oldestAge
        )
    }
}
