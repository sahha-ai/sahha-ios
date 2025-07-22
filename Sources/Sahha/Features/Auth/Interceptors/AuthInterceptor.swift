final class AuthInterceptor: Interceptor {
    private let tokenProvider: TokenProvider

    var priority: Int { 100 }

    init(tokenProvider: TokenProvider) {
        self.tokenProvider = tokenProvider
    }

    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse {
        guard request.requiresAuth else {
            return try await next(request)
        }
        let token = try await tokenProvider.validProfileToken()
        var req = request
        req.addHeader(name: "Authorization", value: "Profile \(token)")
        return try await next(req)
    }
}
