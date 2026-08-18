import Foundation

protocol TokenStoreProtocol: Actor, Disposable {
    func saveToken(_ token: TokenResponse) throws
    func token() -> TokenResponse?
    func profileToken() -> String?
    func refreshToken() -> String?
    /// Clears a dead session (tokens + keychain) while keeping the store usable for a
    /// subsequent `authenticate(...)`. Unlike `dispose()`, this is not a teardown.
    func clearToken()
    /// True when the persisted session could not be read from the keychain (e.g. a
    /// background launch before first device unlock) and nothing has been saved since:
    /// a nil `token()` in this state means "unknown", not "signed out" (PRD #76 D10).
    func hasUnreadablePersistedSession() -> Bool
    /// Retries a failed launch-time keychain read. No-op when the store read cleanly,
    /// was disposed, or a token has been saved since.
    func reloadPersistedSession()
}

extension TokenStoreProtocol {
    func hasUnreadablePersistedSession() -> Bool { false }
    func reloadPersistedSession() {}
}
