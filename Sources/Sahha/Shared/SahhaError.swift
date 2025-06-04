import Foundation

enum SahhaError: Error, CustomStringConvertible {
    case notConfigured
    case noInternet
    case invalidURL(url: String)
    case serverError(statusCode: Int)
    case decodingFailed
    case unauthorized
    case apiError(ApiErrorResponse)
    case keychainError
    case userDefaultsError
    case healthKitUnavailable
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
        switch self {
        case .notConfigured:
            return "Sahha is not configured. Please call Sahha.configure() before using other features."
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
        case .keychainError:
            return "An error occurred while accessing the keychain."
        case .userDefaultsError:
            return "An error occurred while accessing UserDefaults."
        case .healthKitUnavailable:
            return "HealthKit is not available on this device."
        case .unknown:
            return "An unknown error occurred."
        case .custom(let message):
            return message
        }
    }
}

