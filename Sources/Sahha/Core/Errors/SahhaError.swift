import Foundation

enum SahhaError: Error, LocalizedError {
    case notConfigured
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sahha is not configured. Please call `Sahha.configure(...)` before calling this function."
        }
    }
}
