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

        let response = try await next(modifiedRequest)

        if response.response.statusCode == 401 {
            // Optionally refresh token and retry
            print("Token expired, could refresh here and retry")
        }

        return response
    }
}
