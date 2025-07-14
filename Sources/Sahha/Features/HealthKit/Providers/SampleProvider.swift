import HealthKit

protocol SampleProvider: Sendable {
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample]
}

final class SampleProviderImpl: SampleProvider {
    private let authorizationManager: HKAuthorizationManager
    private let sampleQueryHandler: HKSampleQueryHandler
    private let sampleNormaliser: Normaliser<HKSample, SahhaSample>

    init(
        authorizationManager: HKAuthorizationManager,
        sampleQueryHandler: HKSampleQueryHandler,
        sampleNormaliser: Normaliser<HKSample, SahhaSample>,
    ) {
        self.authorizationManager = authorizationManager
        self.sampleQueryHandler = sampleQueryHandler
        self.sampleNormaliser = sampleNormaliser
    }

    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] {
        guard let metadata = SensorMapper.metadata(for: sensor),
            let sampleType = metadata.hkObjectType as? HKSampleType
        else {
            throw SensorError.samplesUnavailable(sensor)
        }

        guard try await authorizationManager.isAuthorized(for: sampleType) else {
            throw SensorError.permissionDenied(sensor)
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDateTime, end: endDateTime)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let samples = try await sampleQueryHandler.fetchSamples(
            for: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sortDescriptors
        )

        return samples.flatMap(sampleNormaliser.normalise)
    }
}
