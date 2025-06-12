struct TokenResponse: Codable, Equatable {
    var profileToken: String
    var refreshToken: String
    var expiresIn: Int = 0
    var tokenType: String = "Profile"
}
