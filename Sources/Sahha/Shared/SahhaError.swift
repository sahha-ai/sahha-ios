import Foundation

enum SahhaError: Error, CustomStringConvertible {
    case notConfigured
    case unauthenticated
    case noInternet
    case invalidURL(url: String)
    case serverError(statusCode: Int)
    case decodingFailed
    case unauthorized
    case apiError(ApiErrorResponse)
    case healthKitUnavailable
    case fileStorage(message: String)
    case unknown
    case custom(message: String)
    
    var apiErrorResponse: ApiErrorResponse? {
        if case let .apiError(response) = self {
            return response
        }
        return nil
    }
    
    var code: Int? {
        switch self {
        case .invalidURL:
            return 400
        case .unauthorized:
            return 401
        case .serverError(let statusCode):
            return statusCode
        case .apiError:
            return apiErrorResponse?.statusCode
        default:
            return nil
        }
    }
    
    var description: String {
        return "[Sahha] " + message
    }
    
    private var message: String {
        switch self {
        case .notConfigured:
            return "Sahha is not configured. Please call Sahha.configure(...) before calling this method."
        case .unauthenticated:
            return "Sahha is unauthenticated. Please call Sahha.authenticate(...) before calling this method."
        case .noInternet:
            return "No internet connection available."
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .serverError(let statusCode):
            return "Server returned an error with status code: \(statusCode)."
        case .decodingFailed:
            return "Failed to decode server response."
        case .unauthorized:
            return "Unauthorized request. Please check credentials or token."
        case .apiError(let response):
            return response.title
        case .healthKitUnavailable:
            return "HealthKit is not available on this device."
        case .fileStorage(let message):
            return "File storage error: \(message)"
        case .unknown:
            return "An unknown error occurred."
        case .custom(let message):
            return message
        }
    }
}

extension SahhaError: LocalizedError {
    var errorDescription: String? {
        return description
    }
}

