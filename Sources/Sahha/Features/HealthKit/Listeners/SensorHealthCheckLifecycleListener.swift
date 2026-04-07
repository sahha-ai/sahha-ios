import Foundation

final class SensorHealthCheckLifecycleListener: LifecycleListener, @unchecked Sendable {
    private let sensorStore: SensorStoreProtocol
    private let observerStore: HealthKitObserverStoreProtocol
    private let healthKitManager: HealthKitManagerProtocol
    private let logger: ErrorLoggerProtocol
    private var diagnosticReportBuilder: DiagnosticReportBuilderProtocol?

    private let _latestResult = LatestResultHolder()

    init(
        sensorStore: SensorStoreProtocol,
        observerStore: HealthKitObserverStoreProtocol,
        healthKitManager: HealthKitManagerProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.sensorStore = sensorStore
        self.observerStore = observerStore
        self.healthKitManager = healthKitManager
        self.logger = logger
    }

    func setDiagnosticReportBuilder(_ builder: DiagnosticReportBuilderProtocol) {
        self.diagnosticReportBuilder = builder
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        let result = await runHealthCheck()
        await _latestResult.set(result)

        if !result.allHealthy {
            Sahha.log("[SensorHealthCheck] Re-registered \(result.sensorsReRegistered.count) observer(s), \(result.failures.count) failure(s)")
        }

        // Upsert diagnostic snapshot after each health check
        _ = await diagnosticReportBuilder?.buildReport()
    }

    func getLatestResult() async -> SensorHealthCheckResult? {
        await _latestResult.get()
    }

    private func runHealthCheck() async -> SensorHealthCheckResult {
        let enabledSensors: Set<SahhaSensor>
        do {
            enabledSensors = try await sensorStore.getSensors()
        } catch {
            return SensorHealthCheckResult(
                timestamp: Date(),
                sensorsChecked: [],
                sensorsReRegistered: [],
                failures: [:]
            )
        }

        guard !enabledSensors.isEmpty else {
            return SensorHealthCheckResult(
                timestamp: Date(),
                sensorsChecked: [],
                sensorsReRegistered: [],
                failures: [:]
            )
        }

        let registeredKeys = await observerStore.getRegisteredKeys()
        let missingSensors = enabledSensors.filter { sensor in
            sensor.hkSampleType != nil && !registeredKeys.contains(sensor.rawValue)
        }

        var reRegistered = Set<SahhaSensor>()
        var failures: [SahhaSensor: String] = [:]

        if !missingSensors.isEmpty {
            Sahha.log("[SensorHealthCheck] Missing observers for: \(missingSensors.map(\.rawValue).sorted().joined(separator: ", "))")

            // Re-register all sensors through the standard flow.
            // resumeSensors() handles the dataLog/tag split and is idempotent
            // for already-registered sensors.
            await healthKitManager.resumeSensors()

            // Verify which sensors were successfully re-registered
            let updatedKeys = await observerStore.getRegisteredKeys()
            for sensor in missingSensors {
                if updatedKeys.contains(sensor.rawValue) {
                    reRegistered.insert(sensor)
                } else {
                    let message = "Observer re-registration failed for \(sensor.rawValue)"
                    failures[sensor] = message
                    logger.postError(SahhaError(message: message))
                }
            }
        }

        return SensorHealthCheckResult(
            timestamp: Date(),
            sensorsChecked: enabledSensors,
            sensorsReRegistered: reRegistered,
            failures: failures
        )
    }
}

private actor LatestResultHolder {
    private var result: SensorHealthCheckResult?

    func set(_ value: SensorHealthCheckResult) {
        result = value
    }

    func get() -> SensorHealthCheckResult? {
        result
    }
}
