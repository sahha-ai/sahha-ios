final class AuthenticationInterceptor: APIInterceptor {
    private let tokenManager: TokenManagerProtocol

    init(tokenManager: TokenManagerProtocol) {
        self.tokenManager = tokenManager
    }

    func intercept(request: APIRequest, next: NextAPIRequest) async throws -> APIResponse {
        var modifiedRequest = request
        if let token = try await tokenManager.ensureValidProfileToken() {
            modifiedRequest.addHeader(name: "Authorization", value: "Profile \(token)")
        }

        return try await next(modifiedRequest)
    }
}
