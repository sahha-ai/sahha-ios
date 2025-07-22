import Foundation

enum ResponseError: LocalizedError {
    case noContent
    case status(Int)
    case api(APIErrorResponse)

    var errorDescription: String? {
        switch self {
        case .noContent: "The server returned 204 No-Content."
        case .status(let code): "Server returned HTTP \(code)."
        case .api(let api): "API error: \(api.title)"
        }
    }
}
