import Foundation

enum ValidationError: LocalizedError {
    case emptyString(field: String)
    case emptyCollection(collection: String)
    case invalidDateRange
    case authenticationRequired
    case validationFailed([ValidationError])

    var errorDescription: String? {
        switch self {
        case .emptyString(let field):
            return "The \(field) feild can not be empty."
        case .emptyCollection(let collection):
            return "The \(collection) collection can not be empty."
        case .invalidDateRange:
            return "Start date must be before or equal to end date."
        case .authenticationRequired:
            return "Authentication required. Please call `Sahha.authenticate(...)` before using this function."
        case .validationFailed(let errors):
            return errors.map { $0.localizedDescription }.joined(separator: "\n")
        }
    }
}
