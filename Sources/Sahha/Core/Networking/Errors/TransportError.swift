import Foundation

enum TransportError:LocalizedError {
    case invalidURL
    case network(Error)
    case nonHTTPResponse(URLResponse)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The base URL or endpoint is malformed."
        case .network(let error): "Network failure: \(error)"
        case .nonHTTPResponse: "Received a non-HTTP response."
        }
    }
}
