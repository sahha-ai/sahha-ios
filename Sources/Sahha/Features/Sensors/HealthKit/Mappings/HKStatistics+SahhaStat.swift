import HealthKit

extension HKStatistics {
    func toSahhaStat(periodicity: StatPeriodicity = .daily) -> SahhaStat? {
        SahhaStat.build(from: self, periodicity: periodicity)
    }
}
