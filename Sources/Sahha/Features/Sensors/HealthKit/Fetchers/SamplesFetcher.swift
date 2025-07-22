import HealthKit

final class SamplesFetcher: Sendable {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }
    
    func fetchSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        guard let sampleType = sensor.hkObjectType as? HKSampleType else {
            throw HealthKitError.invalidSensorType(sensor)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDateTime, end: endDateTime)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        
        let samples = try await HKSampleQuery.sampleQuery(for: sampleType, predicate: predicate, sortDescriptors: sortDescriptors, using: healthStore)
        
        return SahhaSampleNormaliser.normalise(samples, sensor: sensor)
    }
}
