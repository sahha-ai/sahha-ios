import Foundation

final actor TokenManager: TokenManagerProtocol {
    private let authService: AuthenticationServiceProtocol
    private let storage: any KeychainProtocol<TokenResponse>
    private let refreshOffset: TimeInterval

    private var cachedResponse: TokenResponse?
    private var cachedExpiry: Date?
    private var refreshTask: Task<TokenResponse, Error>?

    init(
        authService: AuthenticationServiceProtocol,
        storage: any KeychainProtocol<TokenResponse> = KeychainStorage(key: Constants.Keychain.tokenAccount),
        refreshOffset: TimeInterval = 600  // 10 Minutes

    ) async {
        self.authService = authService
        self.storage = storage
        self.refreshOffset = refreshOffset
        cachedResponse = try? await storage.retrieve()
        await updateSahhaWithToken()
    }

    func saveToken(_ token: TokenResponse) async throws {
        // Save the token to storage
        try await storage.save(token)
        cachedResponse = token
        await updateSahhaWithToken()
    }

    // Helper function to update Sahha with token and expiry
    private func updateSahhaWithToken() async {
        guard let response = cachedResponse else { return }
        let token = response.profileToken

        if !token.isEmpty, let exp = JWTDecoder.decodeExp(jwt: token) {
            let expiry = Date(timeIntervalSince1970: exp)
            cachedExpiry = expiry
            await Sahha.updateToken(token: token, expiry: expiry)
        } else {
            cachedExpiry = nil
            await Sahha.updateToken(token: nil, expiry: nil)
        }
    }

    func getProfileToken() async -> String? {
        if cachedResponse == nil {
            cachedResponse = try? await storage.retrieve()
        }
        return cachedResponse?.profileToken
    }

    func getRefreshToken() async -> String? {
        if cachedResponse == nil {
            cachedResponse = try? await storage.retrieve()
        }
        return cachedResponse?.refreshToken
    }

    func dispose() async throws {
        refreshTask?.cancel()
        refreshTask = nil
        try await removeTokens()
    }

    func removeTokens() async throws {
        try await storage.delete()
        cachedResponse = nil
        cachedExpiry = nil
        refreshTask = nil
        await Sahha.updateToken(token: nil, expiry: nil)
    }

    func ensureValidProfileToken() async throws -> String? {
        guard let token = await getProfileToken() else {
            return nil
        }
        guard await isTokenExpired() else {
            return token
        }
        return try await refreshToken().profileToken
    }

    private func isTokenExpired() async -> Bool {
        guard let expiry = cachedExpiry else {
            guard let token = await getProfileToken(), !token.isEmpty,
                let exp = JWTDecoder.decodeExp(jwt: token)
            else {
                return true
            }
            cachedExpiry = Date(timeIntervalSince1970: exp)
            return Date().addingTimeInterval(refreshOffset) >= cachedExpiry!
        }
        return Date().addingTimeInterval(refreshOffset) >= expiry
    }

    private func refreshToken() async throws -> TokenResponse {
        if let task = refreshTask {
            return try await task.value
        }
        let task = Task {
            defer { refreshTask = nil }
            guard let token = await getRefreshToken(), !token.isEmpty else {
                throw TokenError.noRefreshToken
            }
            let response = try await authService.refreshToken(refreshToken: token)
            try await saveToken(response)
            return response
        }

        refreshTask = task
        return try await task.value
    }
}
