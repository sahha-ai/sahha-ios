import Foundation

protocol DiagnosticReportBuilderProtocol: Sendable {
    func buildReport() async -> DiagnosticReport
    func getLatestReport() async -> DiagnosticReport?
}

actor DiagnosticReportBuilder: DiagnosticReportBuilderProtocol {
    private let sensorStore: SensorStoreProtocol
    private let sensorProbe: SensorProbeServiceProtocol
    private let dataLogUploader: DataLogUploaderProtocol
    private let tagUploader: TagUploaderProtocol
    private let storage: UserDefaultsStorageProtocol
    private let logger: ErrorLoggerProtocol

    private let storageKey = "com.sahha.diagnostic_report"

    init(
        sensorStore: SensorStoreProtocol,
        sensorProbe: SensorProbeServiceProtocol,
        dataLogUploader: DataLogUploaderProtocol,
        tagUploader: TagUploaderProtocol,
        storage: UserDefaultsStorageProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.sensorStore = sensorStore
        self.sensorProbe = sensorProbe
        self.dataLogUploader = dataLogUploader
        self.tagUploader = tagUploader
        self.storage = storage
        self.logger = logger
    }

    func buildReport() async -> DiagnosticReport {
        let enabledSensors: Set<SahhaSensor>
        do {
            enabledSensors = try await sensorStore.getSensors()
        } catch {
            // The report is still built (an empty sensor list IS the dashboard's
            // "No sensor data reported" signal) — but no longer silently: this
            // swallow is how a broken store looked identical to a healthy empty one.
            logger.postError(error)
            enabledSensors = []
        }
        var storedStatuses = await sensorStore.getSensorStatuses()
        if storedStatuses.isEmpty, !enabledSensors.isEmpty {
            // No probe has produced anything yet — the probe's foreground event
            // does not fire on cold launch, so waiting on the listener would
            // report every sensor as all-pending forever on some launches. Probe
            // now, then build. Skipped whenever statuses exist, so warm builds
            // pay no probe wall-clock cost; skipped when the enabled set is
            // empty or unreadable, where there is nothing to probe.
            await sensorProbe.runProbe()
            storedStatuses = await sensorStore.getSensorStatuses()
        }
        let sensorStatuses = Self.backfillStatuses(enabled: enabledSensors, statuses: storedStatuses)

        let dataLogQueueStats = await dataLogUploader.getDLQStatistics()
        let tagQueueStats = await tagUploader.getDLQStatistics()

        let report = DiagnosticReport(
            timestamp: Date(),
            enabledSensors: enabledSensors.map(\.rawValue).sorted(),
            sensorStatuses: Dictionary(
                uniqueKeysWithValues: sensorStatuses.map { ($0.key.rawValue, $0.value.rawValue) }
            ),
            queues: DiagnosticReport.Queues(
                dataLog: queueSnapshot(from: dataLogQueueStats),
                tag: queueSnapshot(from: tagQueueStats)
            )
        )

        do {
            try storage.setObject(report, forKey: storageKey)
        } catch {
            logger.postError(SahhaError(message: "Diagnostic report could not be persisted.", error: error))
        }
        return report
    }

    func getLatestReport() async -> DiagnosticReport? {
        do {
            return try storage.object(forKey: storageKey)
        } catch {
            logger.postError(SahhaError(message: "Stored diagnostic report could not be decoded.", error: error))
            return nil
        }
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
