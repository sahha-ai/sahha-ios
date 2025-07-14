import Foundation

enum SensorError: Error, LocalizedError {
    case healthkitUnavailable
    case permissionDenied(SahhaSensor)
    case samplesUnavailable(SahhaSensor)
    case statsUnavailable(SahhaSensor)
    
    var errorDescription: String? {
        switch self {
        case .healthkitUnavailable:
            return "HealthKit is unavailable on this device."
        case .permissionDenied(let sensor):
            return "User permission is not granted for \(sensor.rawValue)."
        case .samplesUnavailable(let sensor):
            return "Samples are not available for \(sensor.rawValue)"
        case .statsUnavailable(let sensor):
            return "Stats are not available for \(sensor.rawValue)"
        }
    }
}
