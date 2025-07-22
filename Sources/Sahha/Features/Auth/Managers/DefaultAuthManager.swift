import Foundation

final class DefaultAuthManager: AuthManager {
    private let authService: AuthService
    private let tokenProvider: TokenProvider

    init(authService: AuthService, tokenProvider: TokenProvider) {
        self.authService = authService
        self.tokenProvider = tokenProvider
    }

    func authorize(appId: String, appSecret: String, externalId: String) async throws {
        let response = try await authService.registerProfile(appId: appId, appSecret: appSecret, externalId: externalId)
        try await tokenProvider.saveToken(response)
    }

    func authorize(profileToken: String, refreshToken: String) async throws {
        let response = TokenResponse(profileToken: profileToken, refreshToken: refreshToken)
        try await tokenProvider.saveToken(response)
    }
}
