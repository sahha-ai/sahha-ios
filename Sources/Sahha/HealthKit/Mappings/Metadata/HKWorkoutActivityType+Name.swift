import HealthKit

extension HKWorkoutActivityType {
    var name: String {
        String(describing: self).camelToSnake
    }
}
