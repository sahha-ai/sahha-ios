import Foundation

protocol TokenManagerProtocol: Actor, DisposableAsync {
    func saveToken(_ token: TokenResponse) async throws
    func getProfileToken() async -> String?
    func getRefreshToken() async -> String?
    func removeTokens() async throws
    func ensureValidProfileToken() async throws -> String?
}

final actor TokenManager: TokenManagerProtocol {
    private let logger: LoggerProtocol
    private let authService: AuthenticationServiceProtocol
    private let storage: any KeychainProtocol<TokenResponse>
    private let refreshOffset: TimeInterval

    private var cachedResponse: TokenResponse?
    private var cachedExpiry: Date?
    private var refreshTask: Task<TokenResponse, Error>?

    init(
        logger: LoggerProtocol,
        authService: AuthenticationServiceProtocol,
        storage: any KeychainProtocol<TokenResponse> = KeychainStorage(key: Constants.Keychain.tokenAccount),
        refreshOffset: TimeInterval = 600  // 10 Minutes

    ) async {
        self.logger = logger
        self.authService = authService
        self.storage = storage
        self.refreshOffset = refreshOffset
        cachedResponse = try? await storage.retrieve()
        await updateSahhaWithToken()
    }

    func saveToken(_ token: TokenResponse) async throws {
        do {
            try await storage.save(token)
            cachedResponse = token
            await updateSahhaWithToken()
            logger.info("Token saved successfully")
        } catch {
            logger.error("Failed to save token: \(error.localizedDescription)", file: #file, function: #function)
            throw error
        }
    }

    // Helper function to update Sahha with token and expiry
    private func updateSahhaWithToken() async {
        guard let response = cachedResponse else {
            return
        }
        let token = response.profileToken

        if token.isEmpty {
            logger.warning("Token is empty")
            cachedExpiry = nil
            await Sahha.updateToken(token: nil, expiry: nil)
            return
        }

        if let exp = JWTDecoder.decodeExp(jwt: token) {
            let expiry = Date(timeIntervalSince1970: exp)
            cachedExpiry = expiry
            await Sahha.updateToken(token: token, expiry: expiry)
        } else {
            logger.warning("Failed to decode token expiry")
            cachedExpiry = nil
            await Sahha.updateToken(token: nil, expiry: nil)
        }
    }

    func getProfileToken() async -> String? {
        if cachedResponse == nil {
            do {
                cachedResponse = try await storage.retrieve()
            } catch {
                logger.error("Failed to retrieve token from storage: \(error.localizedDescription)", file: #file, function: #function)
                return nil
            }
        }
        return cachedResponse?.profileToken
    }

    func getRefreshToken() async -> String? {
        if cachedResponse == nil {
            do {
                cachedResponse = try await storage.retrieve()
            } catch {
                logger.error("Failed to retrieve token from storage: \(error.localizedDescription)", file: #file, function: #function)
                return nil
            }
        }
        return cachedResponse?.refreshToken
    }

    func dispose() async throws {
        refreshTask?.cancel()
        refreshTask = nil
        do {
            try await removeTokens()
        } catch {
            logger.error("Failed to remove tokens: \(error.localizedDescription)", file: #file, function: #function)
            throw error
        }
    }

    func removeTokens() async throws {
        do {
            try await storage.delete()
            cachedResponse = nil
            cachedExpiry = nil
            refreshTask = nil
            await Sahha.updateToken(token: nil, expiry: nil)
        } catch {
            logger.error("Failed to delete tokens from storage: \(error.localizedDescription)", file: #file, function: #function)
            throw error
        }
    }

    func ensureValidProfileToken() async throws -> String? {
        guard let token = await getProfileToken() else {
            return nil
        }
        guard await isTokenExpired() else {
            return token
        }
        do {
            let refreshedToken = try await refreshToken().profileToken
            return refreshedToken
        } catch {
            logger.error("Failed to refresh token: \(error.localizedDescription)", file: #file, function: #function)
            throw error
        }
    }

    private func isTokenExpired() async -> Bool {
        guard let expiry = cachedExpiry else {
            guard let token = await getProfileToken(), !token.isEmpty else {
                logger.warning("Token is empty")
                return true
            }
            if let exp = JWTDecoder.decodeExp(jwt: token) {
                cachedExpiry = Date(timeIntervalSince1970: exp)
                return Date().addingTimeInterval(refreshOffset) >= cachedExpiry!
            } else {
                logger.warning("Failed to decode token expiry")
                return true
            }
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
                logger.error("No refresh token available", file: #file, function: #function)
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
