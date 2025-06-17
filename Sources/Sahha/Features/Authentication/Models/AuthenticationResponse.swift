struct AuthenticationResponse: Codable {
    let profileToken: String
    let refreshToken: String
    let expiresIn: Int = 0
    let tokenType: String = "Profile"
}
