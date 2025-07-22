import Foundation

enum AuthError: LocalizedError {
    case missingToken
    case invalidToken
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No authentication token was found."
        case .invalidToken:
            return "The authentication token is invalid or corrupted."
        case .unauthorized:
            return "Authentication failed: credentials are no longer valid."
        }
    }
}
