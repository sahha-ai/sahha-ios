import HealthKit

final class HKSahhaSampleFetcher: HKSahhaSampleFetching {
    private let healthStore: HKHealthStore
    private let permissions: HKPermissionsProviding

    init(healthStore: HKHealthStore = .init(), permissions: HKPermissionsProviding) {
        self.healthStore = healthStore
        self.permissions = permissions
    }

    func getSamples(
        for sensor: SahhaSensor,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> [SahhaSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }

        guard let sampleType = sensor.hkSampleType else {
            throw HealthKitError.invalidSensor(sensor)
        }

        guard try await permissions.hasPermission(for: sensor) else {
            throw HealthKitError.permissionDenied(sensor)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDateTime,
            end: endDateTime,
            options: [.strictStartDate, .strictEndDate]
        )

        let samples = try await HKAsyncSampleQuery.execute(
            for: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil,
            using: healthStore
        )

        return await ConcurrentBatchProcessor.run(
            items: samples,
            batchSize: 200,
            maxConcurrentBatches: 4
        ) { batch in
            batch.flatMap { $0.toSahhaSample() }
        }
    }
}
