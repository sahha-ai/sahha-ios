final class ProfileIdProvider: ProfileIdProviderProtocol {
    func profileId() -> String? {
        // Read the cached id, not the token: the token is nil'd when a dead session is cleared,
        // but samples collected until re-auth must keep deriving the same deterministic IDs.
        Sahha.authSnapshot.profileId
    }
}
