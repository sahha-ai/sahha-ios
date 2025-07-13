import Foundation

enum AuthError: Error, LocalizedError {
    case noRefreshToken
    
    var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available."
        }
    }
}
