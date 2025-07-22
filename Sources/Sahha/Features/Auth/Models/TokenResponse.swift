struct TokenResponse: Codable {
    let profileToken: String
    let refreshToken: String
    var expiresIn: Int = 0
    var tokenType: String = "Profile"
}
