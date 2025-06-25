protocol APIInterceptor: Sendable {
    func intercept(_ request: APIRequest) async throws -> APIRequest
}
