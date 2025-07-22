import Foundation

enum SahhaError: LocalizedError {
    case notConfigured
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sahha has not been configured. Please call Sahha.configure(...) first."
        }
    }
}
