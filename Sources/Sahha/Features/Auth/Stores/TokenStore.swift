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

    init(storage: KeychainStorageProtocol, key: String = StorageKeys.Keychain.token, logger: ErrorLoggerProtocol) {
        self.storage = storage
        self.key = key
        self.logger = logger

        do {
            self.cached = try self.storage.object(forKey: key)
            Sahha.authSnapshot.profileToken = cached?.profileToken
            Sahha.authSnapshot.profileId = cached.flatMap { JWT.profileId(from: $0.profileToken) }
        } catch {
        }
    }

    func saveToken(_ token: TokenResponse) throws {
        guard !disposed else {
            throw SahhaError(message: "Token store has been disposed.")
        }
        try storage.setObject(token, forKey: key)
        Sahha.authSnapshot.profileToken = token.profileToken
        Sahha.authSnapshot.profileId = JWT.profileId(from: token.profileToken)
        self.cached = token
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
