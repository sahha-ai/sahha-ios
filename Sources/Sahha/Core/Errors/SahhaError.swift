import HealthKit

struct SahhaError: LocalizedError {
    let message: String
    let error: Error?
    /// Origin of the throw site, captured when the error is created. Error logs report
    /// these instead of the logging call site, which is usually a shared forwarding
    /// helper (e.g. SahhaActor.logError) that says nothing about where the failure was.
    let file: String
    let function: String
    let line: UInt

    init(
        message: String,
        error: Error? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.message = message
        self.error = error
        self.file = file
        self.function = function
        self.line = line
    }

    var errorDescription: String? { message }
}

extension SahhaError {
    static func from(
        _ error: Error,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> SahhaError {
        if let sahhaError = error as? SahhaError {
            return sahhaError
        }
        return SahhaError(message: message(for: error), error: error, file: file, function: function, line: line)
    }

    private static func message(for error: Error) -> String {
        // Handle HealthKit errors
        let nsError = error as NSError
        if nsError.domain == HKErrorDomain {
            switch HKError.Code(rawValue: nsError.code) {
            case .errorHealthDataUnavailable:
                return "Health data is not available on this device."
            case .errorAuthorizationDenied:
                return "Health permissions have not been granted."
            case .errorAuthorizationNotDetermined:
                return "Health permissions have not been requested."
            case .errorUserCanceled:
                return "The HealthKit request was cancelled by the user."
            case .errorNoData:
                return "No HealthKit data available for this sensor."
            default:
                return "A HealthKit error occurred (\(nsError.code))."
            }
        }

        if let apiError = error as? APIErrorResponse {
            let details = apiError.errors.flatMap { $0.errors }.joined(separator: ", ")
            return details.isEmpty ? apiError.title : "\(apiError.title): \(details)"
        }

        // Fallback: generic error
        return error.localizedDescription
    }
}
