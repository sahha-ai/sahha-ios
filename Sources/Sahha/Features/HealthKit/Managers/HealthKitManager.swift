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
        do {
            // Get exsiting sensors and overwrite storage
            let enabledSensors = try await sensorStore.getSensors()
            // Extract previously enabled sensors and stop data collection
            let sensorsToStop = enabledSensors.subtracting(sensors)
            if !sensorsToStop.isEmpty {
                try await dataLogCoordinator.stopDataLogCollection(for: sensorsToStop)
            }
            // Overwrite store with newly enabled sensors
            try await sensorStore.setSensors(sensors)
        } catch {
            logger.postError(error)
        }
    
        // Request permissions and start data collection
        try await permissions.requestPermissions(for: sensors)
        try await dataLogCoordinator.startDataLogCollection(for: sensors)
    }
    
    func resumeSensors() async {
        do {
            let sensors = try await sensorStore.getSensors()
            try await dataLogCoordinator.startDataLogCollection(for: sensors)
        } catch {
            logger.postError(error)
        }
    }
    
    func querySensors() async {
        do {
            let sensors = try await sensorStore.getSensors()
            await dataLogCoordinator.querySensors(sensors)
        } catch {
            logger.postError(error)
        }
    }

    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let status = try await permissions.getPermissionsStatus(for: sensors)
        if case .unnecessary = status { return .enabled }
        return .pending
    }

    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        try await statCoordinator.getStats(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
    }

    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] {
        try await sampleCoordinator.getSamples(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
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
                logger.postError(error)
            }
        }
        if await sensorStore.hasSensor(.date_of_birth) {
            do {
                if let dateOfBirth = try await demographicService.fetchDateOfBirth() {
                    demographic.birthDate = dateOfBirth.isoDate
                }
            } catch {
                logger.postError(error)
            }
        }
        return demographic
    }

    func postInsights() async {
        await activitySummaryUploader.postInsights()
    }
}
