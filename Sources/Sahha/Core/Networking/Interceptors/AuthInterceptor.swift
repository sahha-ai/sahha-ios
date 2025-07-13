final class AuthInterceptor: Interceptor {
    private let tokenManager: TokenManager
    
    init(tokenManager: TokenManager) {
        self.tokenManager = tokenManager
    }
    
    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse {
        var modifiedRequest = request
        if let token = await tokenManager.getProfileToken() {
            modifiedRequest.addHeader(name: "Authorization", value: "Profile \(token)")
        }

        return try await next(modifiedRequest)
    }
}
