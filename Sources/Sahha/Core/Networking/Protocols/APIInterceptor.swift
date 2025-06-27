protocol APIInterceptor: Sendable {
    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse
}

