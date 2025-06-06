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
    
    func setTokens(_ tokens: TokenResponse) throws {
        guard storage.set(tokens) else {
            throw SahhaError.custom(message: "An error occurred while storing tokens")
        }
        
        cached = tokens
        Sahha.setProfileTokenSnapshot(tokens.profileToken)
      
        Task {
            await RefreshTokenManager.shared.scheduleRefresh()
        }
    }
    
    func deleteTokens() throws {
        guard storage.delete() else {
            throw SahhaError.custom(message: "An error occurred while deleting tokens")
        }

        cached = nil
        Sahha.setProfileTokenSnapshot(nil)
    }
}
