protocol AuthenticationServiceProtocol: Actor {
    func authenticate(appId: String, appSecret: String, externalId: String) async throws -> AuthenticationResponse
}

actor AuthenticationService: AuthenticationServiceProtocol {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    func authenticate(appId: String, appSecret: String, externalId: String) async throws -> AuthenticationResponse {
        let request = AuthenticationRequest(externalId: externalId)
        let endpoint = AuthenticationEndpoint(request: request, appId: appId, appSecret: appSecret)
        return try await apiService.send(endpoint, as: AuthenticationResponse.self)
    }
}
