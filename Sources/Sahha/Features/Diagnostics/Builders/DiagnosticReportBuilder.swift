import Foundation

protocol DiagnosticReportBuilderProtocol: Sendable {
    func buildReport() async -> DiagnosticReport
    func getLatestReport() async -> DiagnosticReport?
}

actor DiagnosticReportBuilder: DiagnosticReportBuilderProtocol {
    private let sensorStore: SensorStoreProtocol
    private let healthCheckListener: SensorHealthCheckLifecycleListener
    private let dataLogUploader: DataLogUploaderProtocol
    private let tagUploader: TagUploaderProtocol
    private let circuitBreaker: CircuitBreaker?
    private let networkMonitor: NetworkMonitor
    private let deviceInfoBuilder: DeviceInfoBuilderProtocol
    private let storage: UserDefaultsStorageProtocol

    private let storageKey = "com.sahha.diagnostic_report"

    init(
        sensorStore: SensorStoreProtocol,
        healthCheckListener: SensorHealthCheckLifecycleListener,
        dataLogUploader: DataLogUploaderProtocol,
        tagUploader: TagUploaderProtocol,
        circuitBreaker: CircuitBreaker?,
        networkMonitor: NetworkMonitor,
        deviceInfoBuilder: DeviceInfoBuilderProtocol,
        storage: UserDefaultsStorageProtocol
    ) {
        self.sensorStore = sensorStore
        self.healthCheckListener = healthCheckListener
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
        let sensorStatuses = await sensorStore.getSensorStatuses()

        let healthCheck = await healthCheckListener.getLatestResult()

        let dataLogDLQStats = await dataLogUploader.getDLQStatistics()
        let tagDLQStats = await tagUploader.getDLQStatistics()

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
            observerStatuses: DiagnosticReport.ObserverSnapshot(
                sensorsChecked: healthCheck?.sensorsChecked.map(\.rawValue).sorted() ?? [],
                sensorsReRegistered: healthCheck?.sensorsReRegistered.map(\.rawValue).sorted() ?? [],
                failures: healthCheck?.failures.reduce(into: [String: String]()) {
                    $0[$1.key.rawValue] = $1.value
                } ?? [:],
                lastCheckTimestamp: healthCheck?.timestamp
            ),
            dataLogDLQ: dlqSnapshot(from: dataLogDLQStats),
            tagDLQ: dlqSnapshot(from: tagDLQStats),
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

    private func dlqSnapshot(from stats: PersistenceStatistics) -> DiagnosticReport.DLQSnapshot {
        let oldestAge: TimeInterval?
        if let oldest = stats.oldestTimestamp {
            oldestAge = Date().timeIntervalSince1970 - oldest
        } else {
            oldestAge = nil
        }
        return DiagnosticReport.DLQSnapshot(
            totalBatches: stats.totalBatches,
            totalItems: stats.totalItems,
            failedBatches: stats.failedBatches,
            oldestBatchAge: oldestAge
        )
    }
}
