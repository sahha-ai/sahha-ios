import HealthKit

extension HKSample {
    func toDataLog() async -> DataLog? {
        switch self {
        case let quantity as HKQuantitySample:
            return await quantity.toDataLog_internal()
        case let category as HKCategorySample:
            return await category.toDataLog_internal()
        case let workout as HKWorkout:
            return await workout.toDataLog_internal()
        default:
            return nil
        }
    }
}
