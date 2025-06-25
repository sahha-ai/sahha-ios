final class AuthenticationInterceptor: APIInterceptor {
    private let tokenManager: TokenManagerProtocol

    init(tokenManager: TokenManagerProtocol) {
        self.tokenManager = tokenManager
    }

    func intercept(_ request: APIRequest) async throws -> APIRequest {
        var modifiedRequest = request
        if let token = try await tokenManager.ensureValidProfileToken() {
            modifiedRequest.addHeader(name: "Authorization", value: "Profile \(token)")
        }
        return modifiedRequest
    }
}
