import HealthKit

final class HealthKitService: HealthKitProviding {
    private let permissions: HKPermissionsProviding
    private let dataLogFetcher: HKDataLogFetching
    private let sahhaSampleFetcher: HKSahhaSampleFetching
    private let sahhaStatsFetcher: HKSahhaStatsFetching
    private let logger: ErrorLogger

    init(
        permissions: HKPermissionsProviding,
        dataLogFetcher: HKDataLogFetching,
        sahhaSampleFetcher: HKSahhaSampleFetching,
        sahhaStatsFetcher: HKSahhaStatsFetching,
        logger: ErrorLogger
    ) {
        self.permissions = permissions
        self.dataLogFetcher = dataLogFetcher
        self.sahhaSampleFetcher = sahhaSampleFetcher
        self.sahhaStatsFetcher = sahhaStatsFetcher
        self.logger = logger
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        try await permissions.requestPermissions(for: sensors)
        try await resumeSensors(sensors)
    }
    
    func resumeSensors(_ sensors: Set<SahhaSensor>) async throws {
        for sensor in sensors {
            do {
                try await dataLogFetcher.start(for: sensor)
            } catch {
                logger.sdkError("Failed to start data log fetching for \(sensor)", error: error)
            }
        }
    }
    
    func disableSensors(_ sensors: Set<SahhaSensor>) async throws {
        for sensor in sensors {
            do {
                try await dataLogFetcher.stop(for: sensor)
            } catch {
                logger.sdkError("Failed to stop data log fetching for \(sensor)", error: error)
            }
        }
    }

    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        try await permissions.checkPermissions(for: sensors)
    }
    
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] {
        try await sahhaSampleFetcher.getSamples(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
    }
    
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        try await sahhaStatsFetcher.getStats(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
    }
}
