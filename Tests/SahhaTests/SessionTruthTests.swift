import Testing
import Foundation
@testable import Sahha

// Coverage for truthful session reads (issue #106).
//
// `Sahha.isAuthenticated`/`Sahha.profileToken` and the auth guard read the
// persisted session directly from the keychain through `SessionReading` — the
// old in-memory `AuthSnapshot` cache (populated as a side effect of
// `TokenStore.init` deep inside configure, and false/nil until then) is gone.
// The persisted profileId replaces the snapshot's second field: written only by
// `TokenStore`, surviving session expiry AND process restarts, dying on deauth.
//
// Everything here runs over injected `MockKeychainStorage`/`InMemoryStorage`
// doubles, so the suite is parallel-safe. The two facade property-wiring tests
// that swap the process-global `Sahha.session` seam live in the `.serialized`
// shared suite in SahhaTests.swift instead.

// MARK: - Helpers

/// A JWT carrying the profileId claim `JWT.profileId(from:)` reads.
private func profileJWT(profileId: String, expiresIn: TimeInterval = 3600) -> String {
    encodeJWT(payload: [
        "https://api.sahha.ai/claims/profileId": profileId,
        "exp": Date().timeIntervalSince1970 + expiresIn,
    ])
}

private func seedToken(
    _ keychain: MockKeychainStorage,
    profileToken: String,
    refreshToken: String = jwt(expiresIn: 86_400)
) throws {
    try keychain.setObject(
        TokenResponse(profileToken: profileToken, refreshToken: refreshToken),
        forKey: StorageKeys.Keychain.token.rawValue
    )
}

/// The two error strings whose exact spelling the design pins: the split-brain
/// test proves the guard and the downstream auth manager agree on the first,
/// and the guard-truth test asserts the second replaces it pre-configure.
private let unauthorizedMessage = "Unauthorized. Please call `Sahha.authenticate(...)` first."
private let notConfiguredMessage = "Sahha is not configured. Please call `Sahha.configure(...)` first."

// MARK: - Reader truth

@Suite("Session reader truth (#106)")
struct SessionReaderTruthTests {

    @Test("A persisted session is readable before any configure")
    func persistedSessionReadableWithoutConfigure() throws {
        let keychain = MockKeychainStorage()
        try seedToken(keychain, profileToken: "restored-session-token")

        let reader = SessionReader(keychain: keychain)

        // Nothing was configured, no container exists: the read still lands.
        #expect(reader.profileToken() == "restored-session-token")
    }

    @Test("An empty keychain reads as signed out")
    func emptyKeychainReadsSignedOut() {
        let reader = SessionReader(keychain: MockKeychainStorage())
        #expect(reader.profileToken() == nil)
    }

    @Test("An unreadable keychain is retried on every read — nothing latches")
    func unreadableKeychainRetriesPerRead() throws {
        let keychain = MockKeychainStorage()
        try seedToken(keychain, profileToken: "locked-away-token")
        let readsAfterSeeding = keychain.getCallCount
        keychain.errorToThrow = NSError(domain: "test.keychain", code: -25308)
        let reader = SessionReader(keychain: keychain)

        #expect(reader.profileToken() == nil)
        #expect(reader.profileToken() == nil)
        // Two failed reads hit the keychain twice: no result was cached.
        #expect(keychain.getCallCount == readsAfterSeeding + 2)

        // The keychain heals (e.g. first unlock): the very next read recovers —
        // there is no latch to clear.
        keychain.errorToThrow = nil
        #expect(reader.profileToken() == "locked-away-token")
        #expect(keychain.getCallCount == readsAfterSeeding + 3)
    }

    @Test("Pinned delta: a transient read error blips false for a signed-in user")
    func transientErrorBlipsFalseDeliberately() throws {
        // A synchronous Bool cannot express "unknown"; false is the safe
        // direction, and the async path keeps its distinct unknown state via
        // `TokenStore.loadFailed` (PRD #76 D10). Deliberate — pinned here.
        let keychain = MockKeychainStorage()
        try seedToken(keychain, profileToken: "signed-in-token")
        let reader = SessionReader(keychain: keychain)
        #expect(reader.profileToken() == "signed-in-token")

        keychain.errorToThrow = NSError(domain: "test.keychain", code: -25293)
        #expect(reader.profileToken() == nil)

        keychain.errorToThrow = nil
        #expect(reader.profileToken() == "signed-in-token")
    }

    @Test("No stale truth: clearToken and the deauth purge read back as signed out")
    func clearedSessionsReadSignedOut() async throws {
        let keychain = MockKeychainStorage()
        let store = TokenStore(storage: keychain, userDefaults: InMemoryStorage(), logger: NoopErrorLogger())
        try await store.saveToken(TokenResponse(profileToken: "session-token", refreshToken: "refresh"))
        let reader = SessionReader(keychain: keychain)
        #expect(reader.profileToken() == "session-token")

        await store.clearToken()
        #expect(reader.profileToken() == nil)

        // And after a full deauth purge over a re-seeded keychain.
        try seedToken(keychain, profileToken: "next-session-token")
        #expect(reader.profileToken() == "next-session-token")
        DeauthenticationPurge.run(userDefaults: InMemoryStorage(), keychain: keychain, directories: [])
        #expect(reader.profileToken() == nil)
        #expect(reader.profileToken() == nil)   // every subsequent read agrees
    }

    @Test("Pinned exception: a failed keychain delete holds true honestly, and is logged")
    func failedDeleteHoldsTrueAndIsLogged() async throws {
        let keychain = MockKeychainStorage()
        let logger = RecordingErrorLogger()
        let store = TokenStore(storage: keychain, userDefaults: InMemoryStorage(), logger: logger)
        try await store.saveToken(TokenResponse(profileToken: "undeletable-token", refreshToken: "refresh"))

        keychain.errorToThrow = NSError(domain: "test.keychain", code: -25299)
        await store.clearToken()

        // The failure is visible on the dashboard, not swallowed.
        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "Token store failed to delete the persisted session from the keychain.")
        // The token really is still on disk — it would have resurrected at the
        // next launch anyway — so once the keychain is readable again the
        // property reads true, honestly. (The old in-memory nil masked this.)
        #expect(keychain.storedKeys.contains(StorageKeys.Keychain.token.rawValue))
        keychain.errorToThrow = nil
        let reader = SessionReader(keychain: keychain)
        #expect(reader.profileToken() == "undeletable-token")
    }

    @Test("Pinned delta: an already-expired stored session reads true until the launch verdict clears it")
    func expiredSessionReadsTrueUntilVerdictClearsIt() async throws {
        let keychain = MockKeychainStorage()
        // Both tokens dead: the launch verdict is terminal without any network.
        try seedToken(keychain, profileToken: jwt(expiresIn: -10), refreshToken: jwt(expiresIn: -300))
        let reader = SessionReader(keychain: keychain)

        // At launch, before any verdict: the persisted session exists, so the
        // property reads true (previously false throughout launch — the one
        // delta most likely to reach support, called out in release notes).
        #expect(reader.profileToken()?.isEmpty == false)

        let store = TokenStore(storage: keychain, userDefaults: InMemoryStorage(), logger: NoopErrorLogger())
        let manager = AuthManager(
            authService: MockAuthService(refresh: []),   // must never be called
            tokenStore: store,
            logger: NoopErrorLogger()
        )
        #expect(await manager.launchVerdict() == .terminalSessionExpiry)

        // The verdict cleared the dead session: the property converges to false.
        #expect(reader.profileToken() == nil)
    }
}

// MARK: - Guard truth

@Suite("Auth guard reads the truth (#106)")
struct AuthGuardTruthTests {

    @Test("Pinned delta: a signed-in, never-configured call reports \"not configured\", not \"Unauthorized\"")
    func signedInPreConfigureCallReportsNotConfigured() async throws {
        let keychain = MockKeychainStorage()
        try seedToken(keychain, profileToken: "restored-session-token")
        let actor = SahhaActor()            // real and never configured
        let box = ConfigurationTaskBox()    // no configure ever requested

        let outcome: (String?, Int) = await withCheckedContinuation { (continuation: CheckedContinuation<(String?, Int), Never>) in
            Sahha.runAsyncWithCallback(
                callback: { continuation.resume(returning: ($0, $1)) },
                requiresAuth: true,
                configurationTaskBox: box,
                session: SessionReader(keychain: keychain),
                actor: actor,
                // The task must resolve through the real actor: only that path
                // reaches `requireConfig`. (A literal task closure would return
                // a value and prove nothing.)
                task: {
                    _ = try await actor.authManager()
                    return 1
                },
                defaultErrorValue: -1
            )
        }

        // The guard passed — the stored session is real — and the failure is
        // the truthful one, from resolve. Today's code reports the misleading
        // "Unauthorized" here. (Signed-out pre-configure calls keep exactly
        // that contract — pinned in AuthGatedConfigurationAwaitTests.)
        #expect(outcome.0 == notConfiguredMessage)
        #expect(outcome.1 == -1)
    }

    @Test("Split-brain is benign: a recovered keychain over an empty store fails downstream with the identical message")
    func unlockMidSessionSplitBrainIsBenign() async throws {
        // A locked keychain at init latches the store unreadable (cached == nil)…
        let keychain = MockKeychainStorage()
        try seedToken(keychain, profileToken: profileJWT(profileId: "profile-recovered"))
        keychain.errorToThrow = NSError(domain: "test.keychain", code: -25308)
        let storage = InMemoryStorage()
        let store = TokenStore(storage: keychain, userDefaults: storage, logger: NoopErrorLogger())
        let service = MockAuthService(refresh: [])       // must never be called
        let manager = AuthManager(authService: service, tokenStore: store, logger: NoopErrorLogger())

        // …then the device unlocks: the guard's direct read flips true while the
        // store's async state is still empty. A gated call now passes the guard
        // and fails downstream in `getValidProfileToken` — with the *identical*
        // user-visible message the guard itself would have produced. Only the
        // throw site moves; nothing new is user-visible.
        keychain.errorToThrow = nil
        #expect(SessionReader(keychain: keychain).profileToken() != nil)
        do {
            _ = try await manager.getValidProfileToken()
            Issue.record("an empty store should have thrown")
        } catch let error as SahhaError {
            #expect(error.message == unauthorizedMessage)
        }

        // The `.app_unlocked` trigger then reloads the store and the split heals
        // locally — and the reload's token write-through persists the profileId.
        await store.reloadPersistedSession()
        _ = try await manager.getValidProfileToken()
        #expect(await service.refreshCallCount == 0)
        #expect(storage.string(forKey: StorageKeys.UserDefaults.profileId.rawValue) == "profile-recovered")
    }
}

// MARK: - Persisted profileId lifecycle

@Suite("Persisted profileId lifecycle (#106)")
struct PersistedProfileIdTests {

    @Test("The data-log identity survives expiry and restarts, dies on deauth, and follows re-auth")
    func profileIdLifecycle() async throws {
        let keychain = MockKeychainStorage()
        let storage = InMemoryStorage()
        let key = StorageKeys.UserDefaults.profileId.rawValue

        // Sign in: saving a token persists the id derived from its claim.
        let store = TokenStore(storage: keychain, userDefaults: storage, logger: NoopErrorLogger())
        try await store.saveToken(TokenResponse(
            profileToken: profileJWT(profileId: "profile-a"),
            refreshToken: jwt(expiresIn: 86_400)
        ))
        #expect(storage.string(forKey: key) == "profile-a")

        // Session expiry clears the token but not the identity: data logs
        // collected while signed out keep deriving the same deterministic IDs.
        await store.clearToken()
        #expect(storage.string(forKey: key) == "profile-a")

        // Restart simulation — the wart fix: a fresh tokenless store over the
        // same defaults leaves the id in place. (The old in-memory snapshot
        // lost it here, and an in-process repeat configure nil'd it too.)
        let relaunchedStore = TokenStore(storage: keychain, userDefaults: storage, logger: NoopErrorLogger())
        #expect(storage.string(forKey: key) == "profile-a")
        await relaunchedStore.dispose()
        #expect(storage.string(forKey: key) == "profile-a")

        // Deauthentication is the one death: the purge removes it.
        DeauthenticationPurge.run(userDefaults: storage, keychain: keychain, directories: [])
        #expect(storage.get(forKey: key) == nil)

        // Re-auth as a different profile overwrites cleanly.
        let freshStore = TokenStore(storage: keychain, userDefaults: storage, logger: NoopErrorLogger())
        try await freshStore.saveToken(TokenResponse(
            profileToken: profileJWT(profileId: "profile-b"),
            refreshToken: jwt(expiresIn: 86_400)
        ))
        #expect(storage.string(forKey: key) == "profile-b")
    }

    @Test("ProfileIdProvider reads the persisted key")
    func providerReadsThePersistedKey() async throws {
        let storage = InMemoryStorage()
        let provider = ProfileIdProvider(storage: storage)
        #expect(provider.profileId() == nil)

        let store = TokenStore(storage: MockKeychainStorage(), userDefaults: storage, logger: NoopErrorLogger())
        try await store.saveToken(TokenResponse(
            profileToken: profileJWT(profileId: "profile-a"),
            refreshToken: jwt(expiresIn: 86_400)
        ))

        #expect(provider.profileId() == "profile-a")
        // And, like every consumer, it keeps resolving after session expiry.
        await store.clearToken()
        #expect(provider.profileId() == "profile-a")
    }

    @Test("A token without the profileId claim removes the persisted id (derive-on-write)")
    func claimlessTokenRemovesPersistedId() async throws {
        let storage = InMemoryStorage()
        let key = StorageKeys.UserDefaults.profileId.rawValue
        storage.set("stale-profile", forKey: key)

        let store = TokenStore(storage: MockKeychainStorage(), userDefaults: storage, logger: NoopErrorLogger())
        try await store.saveToken(TokenResponse(
            profileToken: jwt(expiresIn: 3600),   // no profileId claim
            refreshToken: jwt(expiresIn: 86_400)
        ))

        // Set-or-remove mirrors the old derive-on-write contract: identity always
        // reflects the most recently saved token, never a predecessor's.
        #expect(storage.get(forKey: key) == nil)
    }
}
