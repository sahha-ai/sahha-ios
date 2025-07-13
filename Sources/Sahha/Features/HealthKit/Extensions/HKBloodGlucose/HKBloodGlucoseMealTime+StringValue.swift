import HealthKit

extension HKBloodGlucoseMealTime {
    var stringValue: String {
        switch self {
        case .preprandial: return "before_meal"
        case .postprandial: return "after_meal"
        @unknown default: return "unknown"
        }
    }
}
