import Foundation

enum HealthKitError: LocalizedError {
    case healthKitUnavailable
    case invalidSensor(SahhaSensor)
    case permissionDenied(SahhaSensor)
    case noData(SahhaSensor)

    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            return "HealthKit is unavailable on this device."
        case .invalidSensor(let sensor):
            return "No HealthKit data available for \(sensor)."
        case .permissionDenied(let sensor):
            return "Permission denied for \(sensor)."
        case .noData(let sensor):
            return "No data found in HealthKit for sensor: \(sensor.rawValue) during the specified period."
        }
    }
}
