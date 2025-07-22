import HealthKit

class QuantityStatsFetcher {
    let sensor: SahhaSensor
    let periodicity: StatPeriodicity
    let healthStore: HKHealthStore
    
    init(sensor: SahhaSensor, periodicity: StatPeriodicity, healthStore: HKHealthStore = .init()) {
        self.sensor = sensor
        self.periodicity = periodicity
        self.healthStore = healthStore
    }

    func fetch(startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        guard let quantityType = sensor.hkObjectType as? HKQuantityType else {
            throw HealthKitError.invalidSensorType(sensor)
        }

        let (start, interval) = intervalComponents(from: startDateTime)
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endDateTime)
        
        guard let results = try await HKStatisticsCollectionQuery.statisticsQuery(
            for: quantityType,
            predicate: predicate,
            options: sensor.hkStatsOptions,
            anchorDate: start,
            interval: interval,
            using: healthStore
        ) else { return [] }
        
        return results.statistics().compactMap { $0.toSahhaStat(periodicity: periodicity) }
    }

    private func intervalComponents(from date: Date) -> (Date, DateComponents) {
        var components = DateComponents()
        switch periodicity {
        case .daily:
            components.day = 1
            return (Calendar.current.startOfDay(for: date), components)
        case .hourly:
            components.hour = 1
            return (date, components)
        }
    }
}
