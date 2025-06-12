protocol TokenManagerProtocol: Sendable, Disposable {
    func saveToken(_ tokenResponse: TokenResponse) throws
    func getToken() -> String?
    func clearToken() throws
}

final class TokenManager: TokenManagerProtocol {
    private let storage: KeychainStorage<TokenResponse>
    
    init(account: String = "auth_token") {
        self.storage = KeychainStorage<TokenResponse>(account: account)
    }
    
    func saveToken(_ tokenResponse: TokenResponse) throws {
        guard storage.set(tokenResponse) else {
            throw SahhaError.message("Failed to save token")
        }
    }
    
    func getToken() -> String? {
        storage.get()?.profileToken
    }
    
    func clearToken() throws {
        guard storage.delete() else {
            throw SahhaError.message("Failed to delete token")
        }
    }
    
    func dispose() {
        _ = try? clearToken()
        print("TokenManager disposed")
    }
}
