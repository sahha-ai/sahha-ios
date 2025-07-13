import Foundation

protocol TokenManager: Actor, Disposable {
    func saveTokenResponse(_ token: TokenResponse) async throws
    func getProfileToken() async -> String?
}

final actor TokenManagerImpl: TokenManager {
    private let service: AuthService
    private let storage: any KeychainStorage<TokenResponse>
    private let jwtDecoder: JWTDecoder
    private let time: TimeProvider

    private var cachedResponse: TokenResponse?
    private var cachedExpiry: Date?
    private var refreshTask: Task<Void, Error>?

    init(
        service: AuthService,
        storage: some KeychainStorage<TokenResponse>,
        jwtDecoder: JWTDecoder = .init(),
        time: TimeProvider = SystemTime()
    ) async {
        self.service = service
        self.storage = storage
        self.jwtDecoder = jwtDecoder
        self.time = time

        if let stored = try? await storage.retrieve() {
            cachedResponse = stored
            cachedExpiry = extractExpiry(from: stored)
        }
        await Sahha.setAuthSnapshot(
            .init(
                profileToken: cachedResponse?.profileToken,
                expiry: cachedExpiry
            )
        )
    }

    func getProfileToken() async -> String? {
        if !isTokenValid() {
            try? await refreshToken()
        }
        return cachedResponse?.profileToken
    }

    func saveTokenResponse(_ token: TokenResponse) async throws {
        try await storage.save(token)
        cachedResponse = token
        cachedExpiry = extractExpiry(from: token)
        await Sahha.setAuthSnapshot(
            .init(
                profileToken: token.profileToken,
                expiry: cachedExpiry
            )
        )
    }

    func dispose() async {
        refreshTask?.cancel()
        refreshTask = nil
        try? await storage.delete()
        cachedResponse = nil
        cachedExpiry = nil
        await Sahha.setAuthSnapshot(.init(profileToken: nil, expiry: nil))
    }

    private func isTokenValid() -> Bool {
        guard let expiry = cachedExpiry else { return false }
        let refreshLeadTime: TimeInterval = .minutes(30)
        return time.now().addingTimeInterval(refreshLeadTime) < expiry
    }

    private func refreshToken() async throws {
        guard let refresh = cachedResponse?.refreshToken, !refresh.isEmpty else {
            throw AuthError.noRefreshToken
        }
        if let task = refreshTask {
            try await task.value
            return
        }
        refreshTask = Task {
            defer { refreshTask = nil }
            let response = try await service.refreshToken(refreshToken: refresh)
            try await saveTokenResponse(response)
        }
        try await refreshTask!.value
    }

    private func extractExpiry(from response: TokenResponse) -> Date? {
        if let exp = jwtDecoder.expiryDate(from: response.profileToken) { return exp }
        guard response.expiresIn > 0 else { return nil }
        return time.now().addingTimeInterval(TimeInterval(response.expiresIn))
    }
}
