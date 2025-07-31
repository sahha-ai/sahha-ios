import HealthKit

struct SahhaError: LocalizedError {
    let message: String
    let error: Error?

    init(message: String, error: Error? = nil) {
        self.message = message
        self.error = error
    }

    var errorDescription: String? { message }
}

extension SahhaError {
    static func from(_ error: Error) -> SahhaError {
        if let sahhaError = error as? SahhaError {
            return sahhaError
        }

        // Handle HealthKit errors
        let nsError = error as NSError
        if nsError.domain == HKErrorDomain {
            switch HKError.Code(rawValue: nsError.code) {
            case .errorHealthDataUnavailable:
                return SahhaError(message: "Health data is not available on this device.", error: error)
            case .errorAuthorizationDenied:
                return SahhaError(message: "Health permissions have not been granted.", error: error)
            case .errorAuthorizationNotDetermined:
                return SahhaError(message: "Health permissions have not been requested.", error: error)
            case .errorUserCanceled:
                return SahhaError(message: "The HealthKit request was cancelled by the user.", error: error)
            case .errorNoData:
                return SahhaError(message: "No HealthKit data available for this sensor.", error: error)
            default:
                return SahhaError(message: "A HealthKit error occurred (\(nsError.code)).", error: error)
            }
        }

        // Fallback: generic error
        return SahhaError(message: error.localizedDescription, error: error)
    }
}
