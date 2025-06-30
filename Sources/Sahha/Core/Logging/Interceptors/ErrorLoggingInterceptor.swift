import Foundation

final class ErrorLoggingInterceptor: APIInterceptor {
    private let logger: LoggerProtocol
    private let ignoredEndpoints: Set<String> = [Constants.Endpoints.error]
    private let ignoredStatusCodes: Set<Int> = [401]

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse {
        do {
            return try await next(request)
        } catch {
            guard !ignoredEndpoints.contains(request.endpoint) else {
                throw error
            }

            var errorSource: ErrorSource = .sdk
            var errorCode = 500
            var errorLocation: String = request.endpoint
            var errorBody: String?

            if let apiError = error as? APIError {
                switch apiError {
                case .apiError(let apiErrorResponse):
                    errorSource = .api
                    errorCode = apiErrorResponse.statusCode
                    errorLocation = apiErrorResponse.location
                    if let data = try? JSONEncoder().encode(apiErrorResponse) {
                        errorBody = String(data: data, encoding: .utf8)
                    }
                case .serverError(let statusCode):
                    errorSource = .api 
                    errorCode = statusCode
                    errorBody = "Server error with status code \(statusCode)"
                case .invalidURL:
                    errorBody = "Invalid URL"
                case .invalidResponse:
                    errorBody = "Invalid server response"
                case .noContent:
                    errorSource = .api
                    errorCode = 204
                    errorBody = "No content returned"
                case .decodingError(let decodingError):
                    errorBody = "Decoding error: \(decodingError.localizedDescription)"
                case .networkError(let networkError):
                    errorBody = "Network error: \(networkError.localizedDescription)"
                }
            } else {
                let nsError = error as NSError
                errorBody = "NSError: \(nsError.domain) code \(nsError.code)"
            }

            if ignoredStatusCodes.contains(errorCode) {
                throw error
            }

            logger.error(
                error.localizedDescription,
                errorSource: errorSource,
                errorCode: errorCode,
                errorLocation: errorLocation,
                errorBody: errorBody,
            )

            throw error
        }
    }
}
