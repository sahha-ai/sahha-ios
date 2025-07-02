import Foundation

enum HealthKitError: Error, LocalizedError {
    case permissionDenied
    case unknownType
    case emptyRequest
    case noMappedSensors
    case backgroundDeliveryFailed(sensor: String)
    case queryFailed(sensor: String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission to access HealthKit data was denied. Please enable access in the Settings app."
        case .unknownType:
            return "The requested HealthKit data type is not supported or unrecognized."
        case .emptyRequest:
            return "The request cannot be processed because no data types were specified."
        case .noMappedSensors:
            return "No valid HealthKit data types could be mapped for the requested sensors."
        case .backgroundDeliveryFailed(let sensor):
            return "Failed to enable background delivery for \(sensor). Please try again."
        case .queryFailed(let sensor):
            return "Failed to query data for \(sensor). Please ensure permissions are granted and try again."
        }
    }
}
