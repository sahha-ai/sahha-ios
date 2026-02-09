import HealthKit

final class HealthKitSahhaSampleCoordinator: HealthKitSahhaSampleCoordinatorProtocol {
    private let sampleQueryService: HealthKitSampleQueryServiceProtocol
    private let permissions: HealthKitPermissionsServiceProtocol
    private let normaliser: HKSampleToSahhaSampleNormaliserProtocol
    private let logger: ErrorLoggerProtocol

    init(
        sampleQueryService: HealthKitSampleQueryServiceProtocol,
        permissions: HealthKitPermissionsServiceProtocol,
        normaliser: HKSampleToSahhaSampleNormaliserProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.sampleQueryService = sampleQueryService
        self.permissions = permissions
        self.normaliser = normaliser
        self.logger = logger
    }

    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] {
        guard startDateTime <= endDateTime else {
            throw SahhaError(message: "Start date time must be less than or equal to end date time.")
        }
        
        guard let sampleType = sensor.hkSampleType else {
            throw SahhaError(message: "Samples are not available for \(sensor.rawValue).")
        }
        
        guard try await permissions.hasPermissions(for: sensor) else {
            throw SahhaError(message: "User permission needed to collect \(sensor.rawValue) samples.")
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDateTime, end: endDateTime)
        let sortDescriptors: [NSSortDescriptor] = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        do {
            let samples = try await sampleQueryService.runSampleQuery(
                for: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            )
            guard !samples.isEmpty else {
                throw SahhaError(message: "No samples found for \(sensor.rawValue)")
            }

            return samples.flatMap(normaliser.normalise)
        } catch {
            throw error
        }

    }
}
