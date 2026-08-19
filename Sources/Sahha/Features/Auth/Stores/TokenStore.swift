import Foundation

actor TokenStore: TokenStoreProtocol {
    private let key: String
    private let storage: KeychainStorageProtocol
    private let logger: ErrorLoggerProtocol

    private var cached: TokenResponse?
    /// Latched by `dispose()` (container teardown, e.g. deauthentication). A refresh flight
    /// that resolves after teardown must not write tokens back into a wiped store — that would
    /// resurrect the session in the keychain behind the fresh container's back.
    private var disposed = false
    /// Latched when the init-time keychain read throws (e.g. a background launch before
    /// first unlock). While set — and until a save or a successful reload — a nil `cached`
    /// means "unknown", not "signed out" (PRD #76 D10).
    private var loadFailed = false

    init(storage: KeychainStorageProtocol, key: String = StorageKeys.Keychain.token.rawValue, logger: ErrorLoggerProtocol) {
        self.storage = storage
        self.key = key
        self.logger = logger

        do {
            self.cached = try self.storage.object(forKey: key)
            Sahha.authSnapshot.profileToken = cached?.profileToken
            Sahha.authSnapshot.profileId = cached.flatMap { JWT.profileId(from: $0.profileToken) }
        } catch {
            loadFailed = true
            // Previously swallowed. An unreadable keychain leaves the synchronous auth
            // snapshot unpopulated for the whole session — the fingerprint behind
            // wrongly rejected deauthentication — so it must be visible on the dashboard.
            logger.postError(SahhaError(
                message: "Token store failed to read the persisted session from the keychain.",
                error: error
            ))
        }
    }

    func saveToken(_ token: TokenResponse) throws {
        guard !disposed else {
            throw SahhaError(message: "Token store has been disposed.")
        }
        try storage.setObject(token, forKey: key)
        // A successful write proves the keychain usable again, and the saved pair is
        // authoritative over whatever the failed launch read may have hidden.
        loadFailed = false
        Sahha.authSnapshot.profileToken = token.profileToken
        Sahha.authSnapshot.profileId = JWT.profileId(from: token.profileToken)
        self.cached = token
    }

    func hasUnreadablePersistedSession() -> Bool {
        loadFailed && cached == nil
    }

    func reloadPersistedSession() {
        guard loadFailed, cached == nil, !disposed else { return }
        do {
            cached = try storage.object(forKey: key)
            loadFailed = false
            Sahha.authSnapshot.profileToken = cached?.profileToken
            Sahha.authSnapshot.profileId = cached.flatMap { JWT.profileId(from: $0.profileToken) }
            Sahha.log("[TokenStore] Persisted session reloaded after a failed launch read")
        } catch {
            // Still unreadable (e.g. the unlock notification raced the keychain
            // becoming available): keep the latch so the next trigger retries. The
            // init-time read already posted this failure to the dashboard.
            Sahha.log("[TokenStore] Persisted session reload failed: \(error)")
        }
    }

    func token() -> TokenResponse? {
        cached
    }

    func profileToken() -> String? {
        cached?.profileToken
    }

    func refreshToken() -> String? {
        cached?.refreshToken
    }

    /// Clears the dead session so `Sahha.isAuthenticated` flips false, but keeps the store
    /// usable for re-authentication and keeps `authSnapshot.profileId` so data logs collected
    /// while signed out retain a stable identity (their deterministic IDs embed the profile id).
    func clearToken() {
        cached = nil
        Sahha.authSnapshot.profileToken = nil
        do {
            try storage.removeObject(forKey: key)
        } catch {
        }
    }

    func dispose() async {
        disposed = true
        clearToken()
        Sahha.authSnapshot.profileId = nil
    }
}
