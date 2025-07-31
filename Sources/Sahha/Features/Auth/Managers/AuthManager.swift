import Foundation

final class AuthManager: AuthManagerProtocol, Disposable {
    private let authService: AuthServiceProtocol
    private let tokenStore: TokenStoreProtocol
    private let logger: ErrorLoggerProtocol
    private let expiryOffset: TimeInterval

    private let refreshTaskActor = SingleThrowingTaskActor<TokenResponse>()

    init(
        authService: AuthServiceProtocol,
        tokenStore: TokenStoreProtocol,
        logger: ErrorLoggerProtocol,
        expiryOffset: TimeInterval = .minutes(30)
    ) {
        self.authService = authService
        self.tokenStore = tokenStore
        self.logger = logger
        self.expiryOffset = expiryOffset
    }

    func authenticate(appId: String, appSecret: String, externalId: String) async throws {
        guard !appId.isEmpty else {
            throw SahhaError(message: "App id cannot be empty.")
        }
        guard !appSecret.isEmpty else {
            throw SahhaError(message: "App secret cannot be empty.")
        }
        guard !externalId.isEmpty else {
            throw SahhaError(message: "External id cannot be empty.")
        }

        do {
            let response = try await authService.authenticate(appId: appId, appSecret: appSecret, externalId: externalId)
            try await tokenStore.saveToken(response)
        } catch {
            logger.postError(error)
            throw error
        }
    }

    func authenticate(profileToken: String, refreshToken: String) async throws {
        guard !profileToken.isEmpty else {
            throw SahhaError(message: "Profile token cannot be empty.")
        }
        guard !refreshToken.isEmpty else {
            throw SahhaError(message: "Refresh token cannot be empty.")
        }
        do {
            let response = TokenResponse(profileToken: profileToken, refreshToken: refreshToken)
            try await tokenStore.saveToken(response)
        } catch {
            logger.postError(error)
            throw error
        }
    }

    func getValidProfileToken() async throws -> String {
        guard let token = await tokenStore.token() else {
            throw SahhaError(message: "Unauthorized. Please call `Sahha.authenticate(...)` first.")
        }
        guard JWT.isExpired(token.profileToken, offset: expiryOffset) else { return token.profileToken }
        let response = try await refreshToken(refreshToken: token.refreshToken)
        try await tokenStore.saveToken(response)
        return response.profileToken
    }

    func hasValidProfileToken() async -> Bool {
        do {
            _ = try await getValidProfileToken()
            return true
        } catch {
            return false
        }
    }

    private func refreshToken(refreshToken: String) async throws -> TokenResponse {
        try await refreshTaskActor.run {
            try await self.authService.refreshToken(refreshToken: refreshToken)
        }
    }

    func dispose() async {
        await refreshTaskActor.cancel()
    }
}
