import Foundation
import Testing
@testable import Sahha

/// Token refresh against the live API from a real device: the SDK's own AuthManager,
/// AuthService and APIClient, on the phone's network stack.
///
/// Skipped unless sandbox app credentials are passed at run time
/// (TEST_RUNNER_SAHHA_APP_ID / TEST_RUNNER_SAHHA_APP_SECRET). Registers or reuses one
/// profile, external id `sahha-ios-device-tests`, and never runs against production.
@Suite(
    "Token refresh against the live API",
    .serialized,
    .enabled(if: DeviceTestEnv.hasAppCredentials, "Pass TEST_RUNNER_SAHHA_APP_ID and TEST_RUNNER_SAHHA_APP_SECRET to run")
)
struct TokenRefreshDeviceTests {
    private static let externalId = "sahha-ios-device-tests"

    private let environment = DeviceTestEnv.apiEnvironment

    @Test("An expiring token is refreshed through the live endpoint, and the new token authorises requests")
    func proactiveRefreshAgainstTheLiveAPI() async throws {
        let client = APIClient(baseURL: environment.baseURL)
        let service = AuthService(apiClient: client)
        let registered = try await service.authenticate(
            appId: try #require(DeviceTestEnv.appId),
            appSecret: try #require(DeviceTestEnv.appSecret),
            externalId: Self.externalId
        )
        let store = InMemoryTokenStore(registered)

        // An expiry window longer than any token's life makes the freshly registered
        // token count as expiring, so the next call has to refresh, exactly as a token
        // inside its last 30 minutes does in the field.
        let manager = AuthManager(authService: service, tokenStore: store, logger: SilentErrorLogger(), expiryOffset: .days(400))
        try await waitForNextTokenSecond()
        let started = Date()
        let refreshedToken = try await manager.getValidProfileToken()
        let refreshSeconds = Date().timeIntervalSince(started)

        let rotated = try #require(await store.token())
        #expect(refreshedToken != registered.profileToken)
        #expect(rotated.profileToken == refreshedToken)
        #expect(rotated.refreshToken != registered.refreshToken)
        #expect(await store.saveCount == 1)
        #expect(!JWT.isExpired(rotated.profileToken))
        #expect(!JWT.isExpired(rotated.refreshToken))

        // The refreshed token works for an authenticated request through the SDK's own
        // interceptor, with the normal 30-minute window so nothing refreshes again.
        let authedManager = AuthManager(authService: service, tokenStore: store, logger: SilentErrorLogger())
        let interceptors = APIInterceptorStore()
        await interceptors.addInterceptor(AuthorizationInterceptor(authManager: authedManager))
        let authedClient = APIClient(baseURL: environment.baseURL, interceptorStore: interceptors)
        try await authedClient.send(APIRequest(endpoint: APIEndpoints.demographic, method: .GET, requiresAuth: true))
        #expect(await store.saveCount == 1, "A request with a fresh token must not refresh")

        DeviceTestReport.record("token-refresh", [
            "environment": environment.rawValue,
            "refreshSeconds": DeviceTestReport.seconds(refreshSeconds),
            "refreshedProfileTokenExpiresAt": JWT.expiryDate(from: rotated.profileToken).map { ISO8601DateFormatter().string(from: $0) } ?? "unreadable",
            "refreshedRefreshTokenExpiresAt": JWT.expiryDate(from: rotated.refreshToken).map { ISO8601DateFormatter().string(from: $0) } ?? "unreadable",
        ])
    }

    @Test("A refreshed pair can itself be refreshed")
    func chainedRefreshAgainstTheLiveAPI() async throws {
        let service = AuthService(apiClient: APIClient(baseURL: environment.baseURL))
        let registered = try await service.authenticate(
            appId: try #require(DeviceTestEnv.appId),
            appSecret: try #require(DeviceTestEnv.appSecret),
            externalId: Self.externalId
        )
        let store = InMemoryTokenStore(registered)

        // Separate managers: one manager will not refresh the same token twice within
        // 10 seconds by design, and this test wants two real round trips.
        try await waitForNextTokenSecond()
        let first = try await AuthManager(authService: service, tokenStore: store, logger: SilentErrorLogger(), expiryOffset: .days(400))
            .getValidProfileToken()
        try await waitForNextTokenSecond()
        let second = try await AuthManager(authService: service, tokenStore: store, logger: SilentErrorLogger(), expiryOffset: .days(400))
            .getValidProfileToken()

        #expect(first != registered.profileToken)
        #expect(second != first)
        #expect(await store.saveCount == 2)
    }

    @Test("A refresh token the server rejects keeps the session and surfaces the error")
    func rejectedRefreshTokenIsKeptForRetry() async throws {
        let service = AuthService(apiClient: APIClient(baseURL: environment.baseURL))
        let registered = try await service.authenticate(
            appId: try #require(DeviceTestEnv.appId),
            appSecret: try #require(DeviceTestEnv.appSecret),
            externalId: Self.externalId
        )
        // A refresh token that is still in date but not one the server signed: the
        // server answers 400, and 1.4.0 keeps the tokens (only 401/403, or a refresh
        // token expired on the device, end the session).
        let forged = forgedRefreshToken(expiresIn: 86_400)
        let store = InMemoryTokenStore(TokenResponse(profileToken: registered.profileToken, refreshToken: forged))
        let manager = AuthManager(authService: service, tokenStore: store, logger: SilentErrorLogger(), expiryOffset: .days(400))

        let error = await #expect(throws: APIErrorResponse.self) { _ = try await manager.getValidProfileToken() }
        #expect(error?.statusCode == 400)
        #expect(await store.token()?.refreshToken == forged, "A 400 is not proof the session is dead")
    }

    /// Profile tokens carry no issued-at time or id, only an expiry to the second, and
    /// the server signs deterministically: a token minted in the same second as the last
    /// one is byte-identical to it. Waiting past the second lets "the token changed"
    /// prove a real round trip. (Seen on development, 2026-11-27.)
    private func waitForNextTokenSecond() async throws {
        try await Task.sleep(nanoseconds: 1_100_000_000)
    }

    /// A well-formed JWT with a future expiry and a bogus signature.
    private func forgedRefreshToken(expiresIn seconds: TimeInterval) -> String {
        func base64URL(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let header = base64URL(Data(#"{"alg":"HS256","typ":"JWT"}"#.utf8))
        let payload = base64URL(Data(#"{"exp":\#(Int(Date().timeIntervalSince1970 + seconds)),"https://api.sahha.ai/claims/refresh":"True"}"#.utf8))
        return "\(header).\(payload).c2lnbmF0dXJl"
    }
}
