import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case noContent
    case serverError(status: Int)
    case decodingFailed(Error)
    case apiError(APIErrorResponse)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .invalidResponse:
            return "The server response was invalid."
        case .noContent:
            return "No content was returned."
        case .serverError(let status):
            return "Server error with status code \(status)."
        case .decodingFailed(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .apiError(let error):
            return "API error: \(error.title)"
        case.networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
