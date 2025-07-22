final class AuthInterceptor: AuthIntercepting {
    private let authService: AuthServiceProviding
    
    init(authService: AuthServiceProviding) {
        self.authService = authService
    }
    
    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse {
        guard request.requiresAuth else {
            return try await next(request)
        }
        let token = try await authService.validProfileToken()
        var req = request
        req.addHeader(name: "Authorization", value: "Profile \(token)")
        return try await next(req)
    }
}
