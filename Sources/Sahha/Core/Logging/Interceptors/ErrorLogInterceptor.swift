final class ErrorLogInterceptor: ErrorLogIntercepting {
    private let logger: ErrorLogger

    init(logger: ErrorLogger) {
        self.logger = logger
    }

    func intercept(request: APIRequest, next: (APIRequest) async throws -> APIResponse) async throws -> APIResponse {
        do {
            return try await next(request)
        } catch {
            guard request.endpoint != APIEndpoints.error else { throw error }

            if let networkingError = error as? NetworkingError {
                let info = extractApiErrorLogInfo(from: networkingError, request: request)
                logger.apiError(
                    errorCode: info.errorCode,
                    errorLocation: info.errorLocation,
                    errorMessage: info.errorMessage,
                    errorBody: info.errorBody
                )
            }

            throw error
        }
    }

    private func extractApiErrorLogInfo(from error: NetworkingError, request: APIRequest) -> (
        errorCode: Int?,
        errorLocation: String?,
        errorMessage: String?,
        errorBody: String?
    ) {
        // Defaults
        var errorCode: Int? = nil
        var errorLocation: String? = request.endpoint
        var errorMessage: String? = error.localizedDescription
        var errorBody: String? = nil

        switch error {
        case .apiError(let apiErrorResponse):
            errorCode = apiErrorResponse.statusCode
            errorLocation = apiErrorResponse.location
            errorMessage = apiErrorResponse.title
            errorBody = apiErrorResponse.errors
                .map { "\($0.origin): \($0.errors.joined(separator: ", "))" }
                .joined(separator: " | ")
        case .invalidStatusCode(let code):
            errorCode = code
        case .invalidURL(let url):
            errorLocation = url
        case .requestFailed(let underlyingError):
            errorBody = underlyingError.localizedDescription
        case .encodingError(let underlyingError):
            errorBody = underlyingError.localizedDescription
        case .decodingError(let underlyingError):
            errorBody = underlyingError.localizedDescription
        case .noContentForType(let typeName):
            errorBody = typeName
        }

        return (errorCode, errorLocation, errorMessage, errorBody)
    }
}
