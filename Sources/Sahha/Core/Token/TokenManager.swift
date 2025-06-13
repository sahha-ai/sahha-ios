import Foundation

protocol TokenManagerProtocol: Actor {
    func save(_ response: AuthenticationResponse) async throws
    func save(profileToken: String, refreshToken: String) async throws
    func getProfileToken() async -> String?
    func getRefreshToken() async -> String?
    func clear() async throws
    func isTokenExpired() async throws -> Bool
    func ensureValidToken() async throws -> String?
}

protocol RefreshProtocol: Actor {
    func refreshToken(refreshToken: String) async throws
}

enum TokenError: Error, LocalizedError {
    case invalidJWTFormat
    case decodingFailed(Error)
    case missingExpiryClaim
    
    var errorDescription: String? {
        switch self {
        case .invalidJWTFormat:
            return "Invalid JWT format."
        case .decodingFailed(let error):
            return "Failed to decode JWT: \(error.localizedDescription)"
        case .missingExpiryClaim:
            return "JWT missing expiry claim."
        }
    }
}

private struct JWTPayload: Decodable {
    let exp: Double?
}

actor TokenManager: TokenManagerProtocol {
    private let storage: any KeychainStorageProtocol<AuthenticationResponse>
    private let apiService: APIServiceProtocol
    
    private var cached: AuthenticationResponse?
    private var cachedExpiry: Date?
    private var isRefreshing = false
    private var refreshTask: Task<AuthenticationResponse, Error>?
    
    init(storage: any KeychainStorageProtocol<AuthenticationResponse>, apiService: APIServiceProtocol) {
        self.storage = storage
        self.apiService = apiService
        cached = storage.get()
    }
    
    func save(_ response: AuthenticationResponse) async throws {
        try storage.set(response)
        cached = response
        cachedExpiry = try extractExpiry(from: response.profileToken)
    }
    
    func save(profileToken: String, refreshToken: String) async throws {
        let expiry = try extractExpiry(from: profileToken)
        let response = AuthenticationResponse(
            profileToken: profileToken,
            refreshToken: refreshToken,
            expiresIn: Int(expiry.timeIntervalSinceNow),
            tokenType: "Profile"
        )
        try storage.set(response)
        cached = response
        cachedExpiry = expiry
    }
    
    func getProfileToken() async -> String? {
        if cached == nil {
            cached = storage.get()
            cachedExpiry = try? extractExpiry(from: cached?.profileToken)
        }
        return cached?.profileToken
    }
    
    func getRefreshToken() async -> String? {
        if cached == nil {
            cached = storage.get()
            cachedExpiry = try? extractExpiry(from: cached?.profileToken)
        }
        return cached?.refreshToken
    }
    
    func clear() async throws {
        try storage.delete()
        cached = nil
        cachedExpiry = nil
    }
    
    func isTokenExpired() async throws -> Bool {
        guard let token = await getProfileToken(), !token.isEmpty else {
            return true // No token means "expired"
        }
        if cachedExpiry == nil {
            cachedExpiry = try extractExpiry(from: token)
        }
        guard let expiryDate = cachedExpiry else {
            throw TokenError.missingExpiryClaim
        }
        // Refresh 10 minutes early
        let refreshOffset: TimeInterval = 600 // 10 minutes
        return Date().addingTimeInterval(refreshOffset) >= expiryDate
    }
    
    func ensureValidToken() async throws -> String? {
        guard try await isTokenExpired() else {
            return cached?.profileToken
        }
        guard let token = await getRefreshToken(), !token.isEmpty else {
            return nil
        }
        do {
            let response = try await refreshToken(refreshToken: token)
            try await save(response)
            return response.profileToken
        } catch {
            try await clear()
            throw error
        }
    }
    
    private func refreshToken(refreshToken: String) async throws -> AuthenticationResponse {
        if isRefreshing, let task = refreshTask {
            return try await task.value // Await existing refresh
        }
        
        // Start a new refresh
        isRefreshing = true
        let newRefreshTask = Task {
            defer {
                isRefreshing = false
                refreshTask = nil
            }
            
            guard !refreshToken.isEmpty else {
                throw APIError.unauthorized
            }
            
            let request = RefreshTokenRequest(refreshToken: refreshToken)
            let endpoint = RefreshTokenEndpoint(request: request)
            return try await apiService.send(endpoint, as: AuthenticationResponse.self)
        }
        refreshTask = newRefreshTask
        
        return try await newRefreshTask.value
    }
    
    private func extractExpiry(from token: String?) throws -> Date {
        guard let token = token else {
            throw TokenError.invalidJWTFormat
        }
        
        let components = token.split(separator: ".")
        guard components.count == 3 else {
            throw TokenError.invalidJWTFormat
        }
        
        var base64 = String(components[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let paddingLength = 4 - base64.count % 4
        if paddingLength > 0 && paddingLength < 4 {
            base64 += String(repeating: "=", count: paddingLength)
        }
        
        guard let payloadData = Data(base64Encoded: base64) else {
            throw TokenError.invalidJWTFormat
        }
        
        do {
            let payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
            guard let exp = payload.exp else {
                throw TokenError.missingExpiryClaim
            }
            return Date(timeIntervalSince1970: TimeInterval(exp))
        } catch {
            throw TokenError.decodingFailed(error)
        }
    }
}
