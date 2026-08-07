import Foundation

protocol TokenStoreProtocol: Actor, Disposable {
    func saveToken(_ token: TokenResponse) throws
    func token() -> TokenResponse?
    func profileToken() -> String?
    func refreshToken() -> String?
    /// Clears a dead session (tokens + keychain) while keeping the store usable for a
    /// subsequent `authenticate(...)`. Unlike `dispose()`, this is not a teardown.
    func clearToken()
}
