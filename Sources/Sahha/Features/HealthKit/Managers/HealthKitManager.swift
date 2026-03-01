import HealthKit

final class HealthKitManager: HealthKitManagerProtocol {
    private let permissions: HealthKitPermissionsServiceProtocol
    private let sensorStore: SensorStoreProtocol
    private let dataLogCoordinator: HealthKitDataLogCoordinatorProtocol
    private let statCoordinator: HealthKitSahhaStatCoordinatorProtocol
    private let sampleCoordinator: HealthKitSahhaSampleCoordinatorProtocol
    private let demographicService: HealthKitDemographicServiceProtocol
    private let activitySummaryUploader: HealthKitActivitySummaryUploaderProtocol
    private let logger: ErrorLoggerProtocol

    init(
        permissions: HealthKitPermissionsServiceProtocol,
        sensorStore: SensorStoreProtocol,
        dataLogCoordinator: HealthKitDataLogCoordinatorProtocol,
        statCoordinator: HealthKitSahhaStatCoordinatorProtocol,
        sampleCoordinator: HealthKitSahhaSampleCoordinatorProtocol,
        demographicService: HealthKitDemographicServiceProtocol,
        activitySummaryUploader: HealthKitActivitySummaryUploaderProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.permissions = permissions
        self.sensorStore = sensorStore
        self.dataLogCoordinator = dataLogCoordinator
        self.statCoordinator = statCoordinator
        self.sampleCoordinator = sampleCoordinator
        self.demographicService = demographicService
        self.activitySummaryUploader = activitySummaryUploader
        self.logger = logger
    }
    
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        let expanded = SahhaSensor.expanded(sensors)
        do {
            // Get exsiting sensors and overwrite storage
            let enabledSensors = try await sensorStore.getSensors()
            // Extract previously enabled sensors and stop data collection
            let sensorsToStop = enabledSensors.subtracting(expanded)
            if !sensorsToStop.isEmpty {
                try await dataLogCoordinator.stopDataLogCollection(for: sensorsToStop)
            }
            // Overwrite store with newly enabled sensors (granular list for observers/queries)
            try await sensorStore.setSensors(expanded)
        } catch {
            // Non-critical: silent failure
        }
    
        // Request permissions and start data collection (one dialog for all nutrition/reproductive types)
        try await permissions.requestPermissions(for: expanded)
        try await dataLogCoordinator.startDataLogCollection(for: expanded)
    }
    
    func resumeSensors() async {
        do {
            let sensors = try await sensorStore.getSensors()
            try await dataLogCoordinator.startDataLogCollection(for: sensors)
        } catch {
            // Non-critical: silent failure
        }
    }
    
    func querySensors() async -> PostSensorDataResult {
        do {
            let sensors = try await sensorStore.getSensors()
            let results = await dataLogCoordinator.querySensors(sensors)
            return PostSensorDataResult(sensorResults: results)
        } catch {
            // Non-critical: silent failure
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
                // Non-critical: silent failure
            }
        }
        if await sensorStore.hasSensor(.date_of_birth) {
            do {
                if let dateOfBirth = try await demographicService.fetchDateOfBirth() {
                    demographic.birthDate = dateOfBirth.isoDate
                }
            } catch {
                // Non-critical: silent failure
            }
        }
        return demographic
    }

    func postInsights() async {
        await activitySummaryUploader.postInsights()
    }
}
