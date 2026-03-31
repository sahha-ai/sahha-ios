final class ProfileIdProvider: ProfileIdProviderProtocol {
    func profileId() -> String? {
        guard let token = Sahha.authSnapshot.profileToken else { return nil }
        return JWT.profileId(from: token)
    }
}
