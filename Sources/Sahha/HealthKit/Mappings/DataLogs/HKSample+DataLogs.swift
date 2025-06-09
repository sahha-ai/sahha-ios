import HealthKit

extension HKSample {
    func toDataLogs() -> [DataLog]? {
        switch self {
        case let quantity as HKQuantitySample:
            return quantity.toDataLogs_internal()
        case let category as HKCategorySample:
            return category.toDataLogs_internal()
        case let workout as HKWorkout:
            return workout.toDataLogs_internal()
        default:
            return nil
        }
    }
}
