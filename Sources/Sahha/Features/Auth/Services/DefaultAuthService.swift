final class DefaultAuthService: AuthService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func registerProfile(appId: String, appSecret: String, externalId: String) async throws -> TokenResponse {
        let request = APIRequest(
            endpoint: APIEndpoints.register,
            method: .POST,
            headers: ["AppId": appId, "AppSecret": appSecret],
            body: RegisterProfileRequest(externalId: externalId)
        )
        return try await api.send(request)
    }

    func refreshToken(refreshToken: String) async throws -> TokenResponse {
        let request = APIRequest(
            endpoint: APIEndpoints.refreshToken,
            method: .POST,
            body: RefreshTokenRequest(refreshToken: refreshToken)
        )
        return try await api.send(request)
    }
}
