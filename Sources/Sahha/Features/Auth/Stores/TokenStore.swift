import Foundation

actor TokenStore: TokenStoreProtocol {
    private let key: String
    private let storage: KeychainStorageProtocol
    /// Backs the persisted profileId — the data-log identity, which outlives the
    /// session (survives `clearToken`/`dispose`/restarts, dies on deauth).
    /// Required with no default so test suites constructing the real store must
    /// inject `InMemoryStorage` instead of silently writing real defaults.
    private let userDefaults: UserDefaultsStorageProtocol
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

    init(
        storage: KeychainStorageProtocol,
        userDefaults: UserDefaultsStorageProtocol,
        key: String = StorageKeys.Keychain.token.rawValue,
        logger: ErrorLoggerProtocol
    ) {
        self.storage = storage
        self.userDefaults = userDefaults
        self.key = key
        self.logger = logger

        do {
            self.cached = try self.storage.object(forKey: key)
            // Tokenless init leaves the persisted id untouched: it belongs to the
            // last signed-in profile until deauth, so signed-out collection (and a
            // repeat configure while signed out) keeps a stable identity.
            if let token = cached {
                persistProfileId(from: token.profileToken)
            }
        } catch {
            loadFailed = true
            // Previously swallowed. An unreadable keychain reads as signed out for
            // the whole launch — the fingerprint behind wrongly rejected
            // deauthentication — so it must be visible on the dashboard.
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
        persistProfileId(from: token.profileToken)
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
            if let token = cached {
                persistProfileId(from: token.profileToken)
            }
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
    /// usable for re-authentication and leaves the persisted profileId untouched so data logs
    /// collected while signed out retain a stable identity (their deterministic IDs embed the
    /// profile id).
    func clearToken() {
        cached = nil
        do {
            try storage.removeObject(forKey: key)
        } catch {
            // A failed delete leaves the token on disk, so `Sahha.isAuthenticated`
            // keeps reading true — honestly: the session would have resurrected at
            // the next launch anyway. Visible on the dashboard, not swallowed.
            logger.postError(SahhaError(
                message: "Token store failed to delete the persisted session from the keychain.",
                error: error
            ))
        }
    }

    func dispose() async {
        disposed = true
        clearToken()
    }

    /// Derives and persists the data-log identity from a just-read or just-saved
    /// token (set-or-remove, mirroring the old derive-on-write contract). Callers
    /// with no token in hand skip the call entirely — the persisted id outlives
    /// the session and is removed only by the deauthentication purge.
    /// Nonisolated (it touches only the immutable storage handle) so the
    /// synchronous init can call it.
    private nonisolated func persistProfileId(from profileToken: String) {
        if let profileId = JWT.profileId(from: profileToken) {
            userDefaults.set(profileId, forKey: StorageKeys.UserDefaults.profileId.rawValue)
        } else {
            userDefaults.removeObject(forKey: StorageKeys.UserDefaults.profileId.rawValue)
        }
    }
}
