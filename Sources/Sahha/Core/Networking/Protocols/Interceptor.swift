typealias NextAPIRequest = (APIRequest) async throws -> APIResponse

protocol Interceptor: Sendable {
    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse
}
