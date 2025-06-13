import Foundation

enum ValidationError: Error, LocalizedError {
    case emptyCollection(collection: String)
    case invalidDateRange
    
    var errorDescription: String {
        switch self {
        case .emptyCollection(let collection):
            return "\(collection) can not be empty."
        case .invalidDateRange:
            return "Start date must be before or equal to end date."
        }
    }
}
