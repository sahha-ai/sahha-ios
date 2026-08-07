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
        do {
            return try await next(authorized(request, with: token))
        } catch let error as APIErrorResponse where error.statusCode == 401 {
            // The server rejected a token we believed valid locally (clock skew beyond the
            // refresh offset, server-side revocation, or a rotated refresh token). Force a
            // single refresh and retry once. A 401 is rejected before the request is processed,
            // so replaying it is safe.
            let refreshedToken = try await authManager.refreshProfileToken(staleToken: token)
            return try await next(authorized(request, with: refreshedToken))
        }
    }

    private func authorized(_ request: APIRequest, with token: String) -> APIRequest {
        var request = request
        request.addHeader(name: "Authorization", value: "Profile \(token)")
        return request
    }
}
