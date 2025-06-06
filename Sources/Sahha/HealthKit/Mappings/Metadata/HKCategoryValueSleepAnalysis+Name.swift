import HealthKit

extension HKCategoryValueSleepAnalysis {
    var name: String {
        String(describing: self).camelToSnake
    }
}
