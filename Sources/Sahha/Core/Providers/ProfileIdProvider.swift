final class ProfileIdProvider: ProfileIdProviderProtocol {
    private let storage: UserDefaultsStorageProtocol

    init(storage: UserDefaultsStorageProtocol) {
        self.storage = storage
    }

    func profileId() -> String? {
        // Read the persisted id, not the token: the token is cleared when a dead
        // session is cleared, but samples collected until re-auth must keep
        // deriving the same deterministic IDs. `TokenStore` is the single writer
        // of this key; the deauthentication purge is its only remover.
        storage.string(forKey: StorageKeys.UserDefaults.profileId.rawValue)
    }
}
