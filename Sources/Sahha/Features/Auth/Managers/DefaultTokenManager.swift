import Foundation

final actor DefaultTokenManager: TokenProvider {
    private let authService: AuthService
    private let tokenStore: TokenStore

    private var refreshTask: Task<TokenResponse, Error>? = nil

    init(authService: AuthService, tokenStore: TokenStore) {
        self.authService = authService
        self.tokenStore = tokenStore
        
        Task {
            if let profileToken = try? await self.validProfileToken() {
                Sahha.authSnapshot.update(isAuthenticated: true, profileToken: profileToken)
            }
        }
    }
    
    func saveToken(_ token: TokenResponse) async throws {
        try await tokenStore.save(token)
        Sahha.authSnapshot.update(isAuthenticated: true, profileToken: token.profileToken)
    }

    func validProfileToken() async throws -> String {
        guard let current = try await tokenStore.get() else {
            Sahha.authSnapshot.clear()
            throw AuthError.missingToken
        }

        let expiryDate = try decodeExpiry(from: current.profileToken)

        if Date().addingTimeInterval(.minutes(30)) >= expiryDate {
            do {
                let response = try await refereshToken()
                return response.profileToken
            } catch {
                Sahha.authSnapshot.clear()
                throw error
            }
        }

        return current.profileToken
    }
    
    func dispose() async {
        refreshTask?.cancel()
        do {
            try await tokenStore.delete()
        } catch {
            print("Failed to delete token: \(error)")
        }
        Sahha.authSnapshot.clear()
    }

    private func refereshToken() async throws -> TokenResponse {
        if let task = refreshTask {
            return try await task.value
        }

        let task = Task {
            defer { refreshTask = nil }
            guard let current = try await tokenStore.get() else {
                throw AuthError.missingToken
            }
            let newToken = try await authService.refreshToken(refreshToken: current.refreshToken)
            try await saveToken(newToken)
            return newToken
        }
        
        refreshTask = task
        return try await task.value
    }

    private func decodeExpiry(from jwt: String) throws -> Date {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { throw AuthError.invalidToken }
        
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64.append(String(repeating: "=", count: (4 - base64.count % 4) % 4))
        
        guard let data = Data(base64Encoded: base64) else {
            throw AuthError.invalidToken
        }

        struct Payload: Decodable { let exp: TimeInterval }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return Date(timeIntervalSince1970: payload.exp)
    }
}
