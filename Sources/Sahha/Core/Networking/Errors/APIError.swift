import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case noContent
    case serverError(statusCode: Int)
    case decodingError(Error)
    case apiError(APIErrorResponse)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .invalidResponse:
            return "The server response was invalid."
        case .noContent:
            return "No content was returned."
        case .serverError(let statusCode):
            return "Server error with status code \(statusCode)."
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .apiError(let apiErrorResponse):
            return "API error: \(apiErrorResponse.title)"
        }
    }
}
