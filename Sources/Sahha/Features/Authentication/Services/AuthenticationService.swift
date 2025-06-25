final class AuthenticationService: AuthenticationServiceProtocol {
    private let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }

    func registerProfile(appId: String, appSecret: String, externalId: String) async throws -> TokenResponse {
        let request = APIRequest(
            endpoint: "v1/oauth/profile/register/appId",
            method: .POST,
            headers: ["AppId": appId, "AppSecret": appSecret],
            body: RegisterProfileRequest(externalId: externalId)
        )
        return try await apiService.request(request)
    }

    func refreshToken(refreshToken: String) async throws -> TokenResponse {
        let request = APIRequest(
            endpoint: "v1/oauth/profile/refreshToken",
            method: .POST,
            body: RefreshTokenRequest(refreshToken: refreshToken)
        )
        return try await apiService.request(request)
    }
}
