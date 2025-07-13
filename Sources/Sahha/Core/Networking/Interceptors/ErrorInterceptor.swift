import Foundation

final class ErrorInterceptor: Interceptor {
    private let logger: Logger
    private let ignoredEndpoints: Set<String> = [Constants.Endpoints.error]

    init(logger: Logger) {
        self.logger = logger
    }

    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse {
        do {
            return try await next(request)
        } catch {
            guard !ignoredEndpoints.contains(request.endpoint) else {
                throw error
            }
            
            if case APIError.noContent = error {
                throw error
            }

            if let apiError = error as? APIError {
                switch apiError {
                case .apiError(let res):
                    let body = try? String(data: JSONEncoder().encode(res), encoding: .utf8)
                    logger.apiError(
                        res.title,
                        code: res.statusCode,
                        location: res.location,
                        body: body
                    )
                case .serverError(let status):
                    logger.apiError(
                        error.localizedDescription,
                        code: status,
                        location: request.endpoint
                    )
                default:
                    logger.error(error.localizedDescription)
                }
            } else {
                logger.error(error.localizedDescription)
            }
            throw error
        }
    }
}
