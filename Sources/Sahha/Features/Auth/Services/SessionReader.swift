/// Synchronous read of the persisted session, for the facade's `isAuthenticated`/
/// `profileToken` properties and auth guard. Reads the keychain — the source of
/// truth — directly on every call: `SecItemCopyMatching` is thread-safe and
/// sub-millisecond, so no cache (and none of a cache's coherence machinery) is
/// needed between the sync properties and the persisted session.
protocol SessionReading: Sendable {
    func profileToken() -> String?
}

struct SessionReader: SessionReading {
    /// Dependency-free by design (same pattern as `DeauthenticationPurge`), so a
    /// read needs no DI container and works before `configure` has ever run.
    var keychain: KeychainStorageProtocol = KeychainStorage()

    func profileToken() -> String? {
        // A missing item reads as nil without throwing; a genuine keychain error
        // (e.g. a background launch before first unlock) also reads as "no
        // session right now" and is retried on the next read — nothing latches.
        let cached: TokenResponse? = try? keychain.object(forKey: StorageKeys.Keychain.token.rawValue)
        return cached?.profileToken
    }
}
