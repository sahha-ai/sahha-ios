import HealthKit

final class StatsFetcher: Sendable {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }

    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, periodicity: StatPeriodicity = .daily) async throws -> [SahhaStat] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        switch sensor {
        case .sleep:
            return try await SleepStatsFetcher(periodicity: periodicity, healthStore: healthStore).fetch(startDateTime: startDateTime, endDateTime: endDateTime)
        case .exercise:
            return try await ExerciseStatsFetcher(healthStore: healthStore).fetch(startDateTime: startDateTime, endDateTime: endDateTime)
        default:
            return try await QuantityStatsFetcher(sensor: sensor, periodicity: periodicity, healthStore: healthStore).fetch(startDateTime: startDateTime, endDateTime: endDateTime)
        }
    }
}

