final class AuthorizationInterceptor: APIInterceptorProtocol {
    private let authManager: AuthManagerProtocol
    
    init(authManager: AuthManagerProtocol) {
        self.authManager = authManager
    }
    
    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse {
        guard request.requiresAuth else {
            return try await next(request)
        }
        let token = try await authManager.getValidProfileToken()
        var request = request
        request.addHeader(name: "Authorization", value: "Profile \(token)")
        return try await next(request)
    }
}
