import Foundation

enum NetworkingError: LocalizedError {
    case invalidURL(String)
    case requestFailed(Error)
    case apiError(APIErrorResponse)
    case noContentForType(String)
    case invalidStatusCode(Int)
    case encodingError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .requestFailed(let error): return "Request failed: \(error.localizedDescription)"
        case .apiError(let error): return "API error: \(error.title)"
        case .noContentForType(let typeName): return "The server returned no content; cannot decode into \(typeName)."
        case .invalidStatusCode(let code): return "Unexpected status code: \(code)"
        case .encodingError(let error): return "Failed to encode request body: \(error)"
        case .decodingError(let error): return "Failed to decode response body: \(error)"
        }
    }
}
