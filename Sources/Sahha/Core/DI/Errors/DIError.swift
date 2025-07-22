import Foundation

enum DIError: LocalizedError {
    case notRegistered(Any.Type)
    
    var errorDescription: String? {
        switch self {
        case .notRegistered(let type):
            return "Dependency \(type) is not registered"
        }
    }
}
