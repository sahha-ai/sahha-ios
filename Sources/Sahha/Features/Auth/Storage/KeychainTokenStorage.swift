import UIKit

final actor KeychainTokenStorage: TokenStoring {
    private let storage: KeychainStoring
    private let expiryOffset: TimeInterval
    private let key = StorageKeys.Keychain.tokenResponseKey

    private var cached: TokenResponse?

    init(storage: KeychainStoring = KeychainStorage(), expiryOffset: TimeInterval = .minutes(15)) {
        self.storage = storage
        self.expiryOffset = expiryOffset
        
        Task { try? await loadToken() }
    }

    func saveToken(_ response: TokenResponse) async throws {
        try await storage.setCodable(response, forKey: key)
        cached = response
        Sahha.authSnapshot.profileToken = response.profileToken
    }

    func loadToken() async throws -> TokenResponse? {
        if let cached = cached {
            return cached
        }
        let token = try await storage.getCodable(TokenResponse.self, forKey: key)
        cached = token
        Sahha.authSnapshot.profileToken = token?.profileToken
        return token
    }

    func deleteToken() async throws {
        try await storage.delete(forKey: key)
        cached = nil
        Sahha.authSnapshot.profileToken = nil
    }

    func profileToken() async throws -> String? {
        try await loadToken()?.profileToken
    }

    func refreshToken() async throws -> String? {
        try await loadToken()?.refreshToken
    }
    
    func profileTokenExpiryDate() async throws -> Date? {
        guard let jwt = try await profileToken() else { return nil }
        return JWT.expirationDate(from: jwt)
    }

    func isProfileTokenExpired() async throws -> Bool {
        guard let jwt = try await profileToken() else { return true }
        return JWT.isExpired(jwt, offset: expiryOffset)
    }
    
    func dispose() async {
        try? await deleteToken()
    }
}
