typealias NextAPIRequest = (APIRequest) async throws -> APIResponse

protocol Intercepting: Sendable {
    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse
}
