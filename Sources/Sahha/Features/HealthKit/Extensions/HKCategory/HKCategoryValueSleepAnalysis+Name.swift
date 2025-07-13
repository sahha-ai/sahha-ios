import HealthKit

extension HKCategoryValueSleepAnalysis {
    var name: String {
        switch self {
        case .inBed: return "in_bed"
        case .awake: return "awake"
        case .asleepCore: return "light"
        case .asleepDeep: return "deep"
        case .asleepREM: return "rem"
        case .asleepUnspecified, .asleep: return "sleeping"
        @unknown default: return "unknown"
        }
    }
}

