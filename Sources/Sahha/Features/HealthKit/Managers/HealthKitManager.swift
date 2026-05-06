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
        let tagSensors = expanded.filter { $0.category == .reproductive || $0.category == .symptom }
        let dataLogSensors = expanded.subtracting(tagSensors)

        do {
            // Get existing sensors and overwrite storage
            let enabledSensors = try await sensorStore.getSensors()
            // Extract previously enabled sensors and stop data collection
            let sensorsToStop = enabledSensors.subtracting(expanded)
            if !sensorsToStop.isEmpty {
                let tagSensorsToStop = sensorsToStop.filter { $0.category == .reproductive || $0.category == .symptom }
                let dataLogSensorsToStop = sensorsToStop.subtracting(tagSensorsToStop)
                if !dataLogSensorsToStop.isEmpty {
                    try await dataLogCoordinator.stopDataLogCollection(for: dataLogSensorsToStop)
                }
                if !tagSensorsToStop.isEmpty {
                    try await tagCoordinator.stopTagCollection(for: tagSensorsToStop)
                }
            }
            // Overwrite store with newly enabled sensors (granular list for observers/queries)
            try await sensorStore.setSensors(expanded)
        } catch {
        }

        // Request permissions and start data collection (one dialog for all nutrition/reproductive types)
        try await permissions.requestPermissions(for: expanded)
        if !dataLogSensors.isEmpty {
            try await dataLogCoordinator.startDataLogCollection(for: dataLogSensors)
        }
        if !tagSensors.isEmpty {
            try await tagCoordinator.startTagCollection(for: tagSensors)
        }
    }
    
    func resumeSensors() async {
        do {
            let sensors = try await sensorStore.getSensors()
            let tagSensors = sensors.filter { $0.category == .reproductive || $0.category == .symptom }
            let dataLogSensors = sensors.subtracting(tagSensors)
            if !dataLogSensors.isEmpty {
                try await dataLogCoordinator.startDataLogCollection(for: dataLogSensors)
            }
            if !tagSensors.isEmpty {
                try await tagCoordinator.startTagCollection(for: tagSensors)
            }
        } catch {
            Sahha.log("[HealthKitManager] resumeSensors failed: \(error)")
        }
    }
    
    func querySensors() async -> PostSensorDataResult {
        do {
            let sensors = try await sensorStore.getSensors()
            let tagSensors = sensors.filter { $0.category == .reproductive || $0.category == .symptom }
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
            return .pending
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
