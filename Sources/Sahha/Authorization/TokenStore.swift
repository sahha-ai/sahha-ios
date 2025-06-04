final actor TokenStore {
    static let shared = TokenStore()
    
    private let storage = KeychainStorage<TokenResponse>(account: "ai.sahha.ios.auth-tokens")
    private var cached: TokenResponse?
    
    private init() {
        self.cached = storage.get()
    }
    
    func getProfileToken() -> String? {
        cached?.profileToken
    }
    
    func getRefreshToken() -> String? {
        cached?.refreshToken
    }
    
    func getAuthorizationHeader() -> String? {
        guard let token = cached else { return nil }
        
        return "\(token.tokenType) \(token.profileToken)"
    }
    
    func setTokens(_ tokens: TokenResponse) async throws {
        guard storage.set(tokens) else {
            throw SahhaError.keychainError
        }
        
        cached = tokens
        await RefreshTokenManager.shared.scheduleRefresh()
    }
    
    func deleteTokens() throws {
        guard storage.delete() else {
            throw SahhaError.keychainError
        }
        
        cached = nil
    }
}
