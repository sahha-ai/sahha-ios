import HealthKit

extension HKHeartRateMotionContext {
    var stringValue: String {
        switch self {
        case .notSet: return "not_set"
        case .sedentary: return "sedentary"
        case .active: return "active"
        @unknown default: return "unknown"
        }
    }
}
