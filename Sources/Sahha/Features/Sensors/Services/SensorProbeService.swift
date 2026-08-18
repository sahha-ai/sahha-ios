import HealthKit

protocol SensorProbeServiceProtocol: Sendable {
    /// Probes each enabled sensor for recent data and merges the results into
    /// the store's per-sensor statuses. Never throws: probe failures degrade to
    /// `.indeterminate` statuses or posted errors.
    func runProbe() async
}

/// Probes every enabled sensor with a limit-1 sample query to detect potentially
/// denied permissions (HealthKit does not expose read-authorization state).
///
/// Extracted from the probe lifecycle listener (PRD #76 D8) so the diagnostic
/// pipeline can await it directly: the probe's foreground event does not fire on
/// cold launch, and the resume event can fire before listeners register — so
/// report builds must not depend on a listener having run first.
final class SensorProbeService: SensorProbeServiceProtocol, @unchecked Sendable {
    /// Default bounds. Recovered installs can carry 100+ expanded sensors, so an
    /// unbounded sequential probe over a wedged health store could block the
    /// bring-up tail indefinitely; the per-sensor bound keeps one wedged query
    /// from eating the whole budget, and the overall cap bounds the sweep.
    static let defaultSensorTimeout: TimeInterval = 5
    static let defaultOverallTimeout: TimeInterval = 30

    private let sensorStore: SensorStoreProtocol
    private let sampleQueryService: HealthKitSampleQueryServiceProtocol
    private let logger: ErrorLoggerProtocol
    private let sensorTimeout: TimeInterval
    private let overallTimeout: TimeInterval

    init(
        sensorStore: SensorStoreProtocol,
        sampleQueryService: HealthKitSampleQueryServiceProtocol,
        logger: ErrorLoggerProtocol,
        sensorTimeout: TimeInterval = SensorProbeService.defaultSensorTimeout,
        overallTimeout: TimeInterval = SensorProbeService.defaultOverallTimeout
    ) {
        self.sensorStore = sensorStore
        self.sampleQueryService = sampleQueryService
        self.logger = logger
        self.sensorTimeout = sensorTimeout
        self.overallTimeout = overallTimeout
    }

    func runProbe() async {
        let enabledSensors: Set<SahhaSensor>
        do {
            enabledSensors = try await sensorStore.getSensors()
        } catch {
            // Without the store the probe cannot run at all, and every
            // per-sensor status silently stays stale.
            logger.postError(error)
            return
        }

        guard !enabledSensors.isEmpty else { return }

        let sensorStore = self.sensorStore
        let sampleQueryService = self.sampleQueryService
        let sensorTimeout = self.sensorTimeout
        do {
            try await withAbandoningTimeout(
                seconds: overallTimeout,
                operationName: "Sensor probe"
            ) {
                for sensor in enabledSensors {
                    // The overall cap cancels this task. Stop rather than let
                    // cancelled queries race through the rest of the loop —
                    // that would flood the statuses of sensors that were never
                    // actually probed with `.indeterminate`.
                    if Task.isCancelled { break }
                    guard let sampleType = sensor.hkSampleType else { continue }
                    do {
                        let samples = try await withAbandoningTimeout(
                            seconds: sensorTimeout,
                            operationName: "Sensor probe (\(sensor.rawValue))"
                        ) {
                            try await sampleQueryService.runSampleQuery(
                                for: sampleType,
                                predicate: HKQuery.predicateForSamples(
                                    withStart: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
                                    end: Date(),
                                    options: .strictStartDate
                                ),
                                limit: 1,
                                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                            )
                        }
                        // Merged per sensor, not batched at the end, so results
                        // probed before the overall cap fires still land.
                        await sensorStore.mergeSensorStatuses([sensor: samples.isEmpty ? .indeterminate : .enabled])
                    } catch is CancellationError {
                        break
                    } catch {
                        // Per-sensor timeout or query failure: probed but unanswered.
                        await sensorStore.mergeSensorStatuses([sensor: .indeterminate])
                    }
                }
            }
        } catch {
            // Overall cap fired (or the caller was cancelled — the raw post
            // keeps a top-level CancellationError filtered out by the logger).
            logger.postError(error)
        }
    }
}
