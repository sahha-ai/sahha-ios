protocol AuthService: Sendable {
    func registerProfile(appId: String, appSecret: String, externalId: String) async throws -> TokenResponse
    func refreshToken(refreshToken: String) async throws -> TokenResponse
}

final class AuthServiceImpl: AuthService {
    private let api: APIService
    
    init(api: APIService) {
        self.api = api
    }
    
    func registerProfile(appId: String, appSecret: String, externalId: String) async throws -> TokenResponse {
        let request = APIRequest(
            endpoint: Constants.Endpoints.registerProfile,
            method: .POST,
            headers: ["AppId": appId, "AppSecret": appSecret],
            body: RegisterProfileRequest(externalId: externalId)
        )
        return try await api.send(request)
    }
    
    func refreshToken(refreshToken: String) async throws -> TokenResponse {
        let request = APIRequest(
            endpoint: Constants.Endpoints.refreshToken,
            method: .POST,
            body: RefreshTokenRequest(refreshToken: refreshToken)
        )
        return try await api.send(request)
    }
}
