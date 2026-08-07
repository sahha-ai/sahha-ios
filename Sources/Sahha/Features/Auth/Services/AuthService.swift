import Foundation

final class AuthService: AuthServiceProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func authenticate(appId: String, appSecret: String, externalId: String) async throws -> TokenResponse {
        let request = APIRequest(
            endpoint: APIEndpoints.register,
            method: .POST,
            headers: ["AppId": appId, "AppSecret": appSecret],
            body: RegisterRequest(externalId: externalId)
        )
        return try await apiClient.send(request)
    }

    func refreshToken(refreshToken: String) async throws -> TokenResponse {
        // This request must NEVER set requiresAuth: the AuthorizationInterceptor would re-enter
        // token refresh from inside the refresh call itself and self-join the in-flight task,
        // deadlocking until the URLSession timeout.
        let request = APIRequest(
            endpoint: APIEndpoints.refreshToken,
            method: .POST,
            body: RefreshTokenRequest(refreshToken: refreshToken),
        )
        return try await apiClient.send(request)
    }
}
