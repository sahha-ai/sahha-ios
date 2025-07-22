import Foundation

final actor AuthService: AuthServiceProviding {
    private let apiClient: APIClientProviding
    private let tokenStore: TokenStoring

    private var refreshTask: Task<Void, Error>?
    private var refreshTimer: Timer?

    init(apiClient: APIClientProviding, tokenStore: TokenStoring) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore

        Task { await scheduleTokenRefresh() }
    }

    func authenticate(appId: String, appSecret: String, externalId: String) async throws {
        let response: TokenResponse = try await apiClient.send(.authenticate(appId: appId, appSecret: appSecret, externalId: externalId))
        try await tokenStore.saveToken(response)
        await scheduleTokenRefresh()
    }
    
    func authenticate(profileToken: String, refreshToken: String) async throws {
        let response = TokenResponse(profileToken: profileToken, refreshToken: refreshToken)
        try await tokenStore.saveToken(response)
        await scheduleTokenRefresh()
    }

    func validProfileToken() async throws -> String {
        try await refreshIfNeeded()
        guard let token = try await tokenStore.profileToken() else {
            throw AuthError.noProfileToken
        }
        return token
    }

    private func refreshIfNeeded() async throws {
        if let task = refreshTask {
            do { try await task.value } catch is CancellationError { return }
            return
        }

        defer { refreshTask = nil }

        refreshTask = Task {
            if try await tokenStore.isProfileTokenExpired() {
                guard let refreshToken = try await tokenStore.refreshToken() else {
                    throw AuthError.noRefreshToken
                }
                let response: TokenResponse = try await apiClient.send(.refreshToken(refreshToken))
                try await tokenStore.saveToken(response)
                await scheduleTokenRefresh()
            }
        }

        do { try await refreshTask?.value } catch is CancellationError { return }
    }

    private func scheduleTokenRefresh() async {
        refreshTimer?.invalidate()

        guard let expiryDate = try? await tokenStore.profileTokenExpiryDate() else { return }
        let now = Date()
        // Schedule to refresh 3 minutes before expiry
        let fireDate = expiryDate.addingTimeInterval(-180)
        let interval = max(fireDate.timeIntervalSince(now), 10)  // at least 10 seconds from now

        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task {
                try? await self?.refreshIfNeeded()
            }
        }
    }
    
    func dispose() async {
        refreshTask?.cancel()
        refreshTimer?.invalidate()
    }
}
