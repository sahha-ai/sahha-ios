import Foundation

enum DIError: Error, LocalizedError {
    case serviceNotRegistered(String)
    case invalidFactoryResult(String)
    case disposalFailed([Error])

    var errorDescription: String? {
        switch self {
        case .serviceNotRegistered(let service):
            return "Service not registered: \(service)"
        case .invalidFactoryResult(let service):
            return "Invalid factory result for service: \(service)"
            case .disposalFailed(let errors):
            return "Disposal failed: \(errors.map(\.localizedDescription).joined(separator: ", "))"
        }
    }
}
