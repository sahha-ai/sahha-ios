import Foundation

enum SensorError: Error, LocalizedError {
    case noHealthKitMapping(SahhaSensor)
    case permissionDenied(SahhaSensor)
    
    var errorDescription: String? {
        switch self {
        case .noHealthKitMapping(let sensor):
            return "HealthKit data is not available for \(sensor.rawValue)"
        case .permissionDenied(let sensor):
            return "User permission is not granted for \(sensor.rawValue)"
        }
    }
}
