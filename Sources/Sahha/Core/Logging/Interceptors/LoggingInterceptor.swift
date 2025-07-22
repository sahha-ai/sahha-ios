import Foundation

final class LoggingInterceptor: Interceptor {
    private let logger: Logger

    var priority: Int { 10 }

    init(logger: Logger) {
        self.logger = logger
    }

    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse {
        do {
            return try await next(request)
        } catch {
            // Ignore errors from error endpoint
            if request.endpoint == APIEndpoints.error {
                throw error
            }
            
            if let transportError = error as? TransportError {
                logger.error(error.localizedDescription)
            } else if let responseError = error as? ResponseError {
                let body = (try? String(data: JSONEncoder().encode(request.body), encoding: .utf8)) ?? ""
                switch responseError {
                case .api(let apiError):
                    logger.apiError(error.localizedDescription, code: apiError.statusCode, location: apiError.location, body: body)
                case .status(let status):
                    logger.apiError(error.localizedDescription, code: status, location: request.endpoint, body: body)
                default:
                    // Ignore other errors eg. ResponseError.noContent
                    break
                }
            }
            
            throw error
        }
    }
}
