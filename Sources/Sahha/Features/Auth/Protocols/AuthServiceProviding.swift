protocol AuthServiceProviding: Actor, Disposable {
    func authenticate(appId: String, appSecret: String, externalId: String) async throws
    func authenticate(profileToken: String, refreshToken: String) async throws
    func validProfileToken() async throws -> String
}
