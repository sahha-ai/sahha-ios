struct TokenResponse: Codable, Equatable {
    var profileToken: String
    var refreshToken: String
    var expiresIn: Int
    var tokenType: String
}
