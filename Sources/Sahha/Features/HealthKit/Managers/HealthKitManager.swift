import HealthKit

final class HealthKitManager: HealthKitManagerProtocol {
    private let permissions: HealthKitPermissionsServiceProtocol
    private let sensorStore: SensorStoreProtocol
    private let dataLogCoordinator: HealthKitDataLogCoordinatorProtocol
    private let tagCoordinator: HealthKitTagCoordinatorProtocol
    private let statCoordinator: HealthKitSahhaStatCoordinatorProtocol
    private let sampleCoordinator: HealthKitSahhaSampleCoordinatorProtocol
    private let demographicService: HealthKitDemographicServiceProtocol
    private let activitySummaryUploader: HealthKitActivitySummaryUploaderProtocol
    private let logger: ErrorLoggerProtocol

    init(
        permissions: HealthKitPermissionsServiceProtocol,
        sensorStore: SensorStoreProtocol,
        dataLogCoordinator: HealthKitDataLogCoordinatorProtocol,
        tagCoordinator: HealthKitTagCoordinatorProtocol,
        statCoordinator: HealthKitSahhaStatCoordinatorProtocol,
        sampleCoordinator: HealthKitSahhaSampleCoordinatorProtocol,
        demographicService: HealthKitDemographicServiceProtocol,
        activitySummaryUploader: HealthKitActivitySummaryUploaderProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.permissions = permissions
        self.sensorStore = sensorStore
        self.dataLogCoordinator = dataLogCoordinator
        self.tagCoordinator = tagCoordinator
        self.statCoordinator = statCoordinator
        self.sampleCoordinator = sampleCoordinator
        self.demographicService = demographicService
        self.activitySummaryUploader = activitySummaryUploader
        self.logger = logger
    }
    
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        let expanded = SahhaSensor.expanded(sensors)
        // Empty-set guard first, before any write or teardown: a bad call must
        // not wipe the persisted set and stop collection on its way to the error.
        guard !expanded.isEmpty else {
            throw SahhaError(message: "Sensor set cannot be empty.")
        }
        let tagSensors = expanded.filter { $0.dataLogType == .reproductive || $0.dataLogType == .symptom }
        let dataLogSensors = expanded.subtracting(tagSensors)

        // Write-always store phase: the requested set is persisted unconditionally,
        // before any teardown that could fail. A store failure is posted and enable
        // continues off the in-memory set — the empty catch that used to wrap this
        // phase both hid and perpetuated the poisoned-store incident.
        var previousSensors: Set<SahhaSensor> = []
        do {
            previousSensors = try await sensorStore.replaceSensors(expanded)
        } catch {
            logger.postError(SahhaError(message: "The sensor store failed while enabling sensors.", error: error))
        }

        let previousHealthKitBacked = previousSensors.filter { !$0.hkPermissions.isEmpty }
        let newHasHealthKitBacked = expanded.contains { !$0.hkPermissions.isEmpty }
        if !previousHealthKitBacked.isEmpty, !newHasHealthKitBacked {
            // Zero-HealthKit-backed guard: replacing a HealthKit-backed set with one
            // containing none is almost always unintended, so the write stands but
            // HealthKit teardown is skipped and the replacement is reported. Never
            // throws, and device-side collection below still starts — all-non-HealthKit
            // sets remain a supported flow on their own.
            logger.postError(SahhaError(message: "enableSensors replaced \(previousHealthKitBacked.count) HealthKit-backed sensor(s) with a set containing none; the new set was persisted, but HealthKit teardown was skipped and the replaced sensors may keep collecting until the next launch."))
        } else {
            // Best-effort teardown of removed sensors, after the write so a stop
            // failure can never block persistence. Each stop is caught independently —
            // one coordinator's failure must not skip the other's stop. Fail-open:
            // sensors whose stop failed keep collecting for this process lifetime.
            let sensorsToStop = previousSensors.subtracting(expanded)
            if !sensorsToStop.isEmpty {
                let tagSensorsToStop = sensorsToStop.filter { $0.dataLogType == .reproductive || $0.dataLogType == .symptom }
                let dataLogSensorsToStop = sensorsToStop.subtracting(tagSensorsToStop)
                if !dataLogSensorsToStop.isEmpty {
                    do {
                        try await dataLogCoordinator.stopDataLogCollection(for: dataLogSensorsToStop)
                    } catch {
                        logger.postError(error)
                    }
                }
                if !tagSensorsToStop.isEmpty {
                    do {
                        try await tagCoordinator.stopTagCollection(for: tagSensorsToStop)
                    } catch {
                        logger.postError(error)
                    }
                }
            }
        }

        // Request permissions and start data collection (one dialog for all nutrition/reproductive types)
        try await permissions.requestPermissions(for: expanded)

        // Post-grant setup must never leave the caller's callback waiting indefinitely.
        // If it exceeds the timeout, the work continues in the abandoned background task
        // (and observers self-heal via resumeSensors on the next launch); the timeout is
        // logged rather than thrown. Each side arms independently — the set is already
        // persisted, so a data-log failure is posted rather than thrown and must not
        // kill reproductive/symptom arming (or vice versa). The raw error is posted so
        // a cancelled abandoned task stays filtered out.
        let dataLogCoordinator = self.dataLogCoordinator
        let tagCoordinator = self.tagCoordinator
        let logger = self.logger
        do {
            try await withAbandoningTimeout(
                seconds: 60,
                operationName: "Sensor data collection setup"
            ) {
                if !dataLogSensors.isEmpty {
                    do {
                        try await dataLogCoordinator.startDataLogCollection(for: dataLogSensors)
                    } catch {
                        logger.postError(error)
                    }
                }
                if !tagSensors.isEmpty {
                    do {
                        try await tagCoordinator.startTagCollection(for: tagSensors)
                    } catch {
                        logger.postError(error)
                    }
                }
            }
        } catch let error as AsyncTimeoutError {
            logger.postError(error)
        }
    }
    
    func resumeSensors() async {
        let sensors: Set<SahhaSensor>
        do {
            sensors = try await sensorStore.getSensors()
        } catch {
            // A failed launch-time resume means no observers for the whole process —
            // previously only a local debug line, invisible on the dashboard.
            logger.postError(error)
            Sahha.log("[HealthKitManager] resumeSensors failed: \(error)")
            return
        }
        await armSensors(sensors)
    }

    func resumeSensors(for sensors: Set<SahhaSensor>) async {
        let enabledSensors: Set<SahhaSensor>
        do {
            enabledSensors = try await sensorStore.getSensors()
        } catch {
            logger.postError(error)
            return
        }
        // Fresh read at arm time: a sensor torn down since the caller computed
        // its missing set intersects away instead of being resurrected.
        let target = sensors.intersection(enabledSensors)
        guard !target.isEmpty else { return }
        await armSensors(target)
    }

    /// Arms the data-log and tag sides independently: one coordinator's failure
    /// is posted and must not prevent the other side from arming. The shared
    /// catch this replaces let a data-log failure silently kill all
    /// reproductive/symptom arming.
    private func armSensors(_ sensors: Set<SahhaSensor>) async {
        let tagSensors = sensors.filter { $0.dataLogType == .reproductive || $0.dataLogType == .symptom }
        let dataLogSensors = sensors.subtracting(tagSensors)
        if !dataLogSensors.isEmpty {
            do {
                try await dataLogCoordinator.startDataLogCollection(for: dataLogSensors)
            } catch {
                logger.postError(error)
                Sahha.log("[HealthKitManager] data-log arming failed: \(error)")
            }
        }
        if !tagSensors.isEmpty {
            do {
                try await tagCoordinator.startTagCollection(for: tagSensors)
            } catch {
                logger.postError(error)
                Sahha.log("[HealthKitManager] tag arming failed: \(error)")
            }
        }
    }
    
    func querySensors() async -> PostSensorDataResult {
        do {
            let sensors = try await sensorStore.getSensors()
            let tagSensors = sensors.filter { $0.dataLogType == .reproductive || $0.dataLogType == .symptom }
            let dataLogSensors = sensors.subtracting(tagSensors)
            var results: [SensorQueryResult] = []
            if !dataLogSensors.isEmpty {
                results.append(contentsOf: await dataLogCoordinator.querySensors(dataLogSensors))
            }
            if !tagSensors.isEmpty {
                results.append(contentsOf: await tagCoordinator.querySensors(tagSensors))
            }
            return PostSensorDataResult(sensorResults: results)
        } catch {
            logger.postError(error)
            return PostSensorDataResult(sensorResults: [], errorDescription: error.localizedDescription)
        }
    }

    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        let expanded = SahhaSensor.expanded(sensors)
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let status = try await permissions.getPermissionsStatus(for: expanded)
        guard case .unnecessary = status else { return .pending }
        let enabledSensors: Set<SahhaSensor>
        do {
            enabledSensors = try await sensorStore.getSensors()
        } catch {
            // Truthful status (PRD #76 D5a): a store failure surfaces as an error,
            // not the success-shaped (nil, .pending) that hid the poisoned-store
            // incident from wrapper SDKs. Posted here too, so the site stays
            // observable off the public callback path; the shared origin dedups
            // the facade's own log of the rethrow.
            let statusError = SahhaError(message: "Sensor status could not be read from the sensor store.", error: error)
            logger.postError(statusError)
            throw statusError
        }
        guard expanded.isSubset(of: enabledSensors) else { return .pending }

        // Check per-sensor probe results — map .indeterminate to .enabled
        // for backward compatibility. Per-sensor breakdown will be exposed
        // in a future release.
        let statuses = await sensorStore.getSensorStatuses()
        for sensor in expanded {
            if let sensorStatus = statuses[sensor], sensorStatus == .indeterminate {
                // Internally tracked but externally reported as .enabled
                continue
            }
        }
        return .enabled
    }

    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        let sensors = SahhaSensor.expanded([sensor])
        var allStats: [SahhaStat] = []
        for sensor in sensors {
            do {
                let stats = try await statCoordinator.getStats(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
                allStats.append(contentsOf: stats)
            } catch {
                // Individual sensor failures are non-critical; continue collecting from others
            }
        }
        guard !allStats.isEmpty else {
            throw SahhaError(message: "No stats were found for the given date range.")
        }
        return allStats
    }

    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] {
        let sensors = SahhaSensor.expanded([sensor])
        var allSamples: [SahhaSample] = []
        for sensor in sensors {
            do {
                let samples = try await sampleCoordinator.getSamples(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
                allSamples.append(contentsOf: samples)
            } catch {
                // Individual sensor failures are non-critical; continue collecting from others
            }
        }
        guard !allSamples.isEmpty else {
            throw SahhaError(message: "No samples were found for the given date range.")
        }
        return allSamples
    }

    func getDemographic() async throws -> SahhaDemographic {
        var demographic = SahhaDemographic()
        if await sensorStore.hasSensor(.gender) {
            do {
                let gender = try await demographicService.fetchGender()
                switch gender {
                case .female: demographic.gender = "female"
                case .male: demographic.gender = "male"
                case .other: demographic.gender = "gender diverse"
                default: break
                }
            } catch {
            }
        }
        if await sensorStore.hasSensor(.date_of_birth) {
            do {
                if let dateOfBirth = try await demographicService.fetchDateOfBirth() {
                    demographic.birthDate = dateOfBirth.isoDate
                }
            } catch {
            }
        }
        return demographic
    }

    func postInsights() async {
        await activitySummaryUploader.postInsights()
    }
}
