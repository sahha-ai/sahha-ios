import Foundation

enum AuthError: LocalizedError {
    case noProfileToken
    case noRefreshToken

    var errorDescription: String? {
        switch self {
        case .noProfileToken:
            return "Profile token is missing or expired."
        case .noRefreshToken:
            return "Refresh token is missing or expired."
        }
    }
}
