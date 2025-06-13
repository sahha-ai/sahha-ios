struct AuthenticationResponse: Codable {
    let profileToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
}
