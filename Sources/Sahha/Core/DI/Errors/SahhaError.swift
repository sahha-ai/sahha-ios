import Foundation

enum SahhaError: Error, LocalizedError {
    case notConfigured
    case missingConfiguration

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sahha is not configured. Please call Sahha.configure(...) before calling this function."
        case .missingConfiguration:
            return "Configuration settings are missing during deauthentication. Ensure Sahha was properly configured."
        }
    }
}
