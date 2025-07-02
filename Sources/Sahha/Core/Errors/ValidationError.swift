import Foundation

enum ValidationError: Error, LocalizedError {
    case emptyString(field: String)
    case emptyCollection(collection: String)
    case invalidDateRange
    
    var errorDescription: String? {
        switch self {
        case .emptyString(field: let field):
            return "The \(field) feild can not be empty."
        case .emptyCollection(let collection):
            return "The \(collection) collection can not be empty."
        case .invalidDateRange:
            return "Start date must be before or equal to end date."
        }
    }
}
