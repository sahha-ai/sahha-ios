import Foundation

protocol SecureAPIServiceProtocol: APIServiceProtocol {}

actor SecureAPIService: SecureAPIServiceProtocol {
    private let apiService: APIServiceProtocol
    private let tokenManager: TokenManagerProtocol
    
    init(apiService: APIServiceProtocol, tokenManager: TokenManagerProtocol) {
        self.apiService = apiService
        self.tokenManager = tokenManager
    }
    
    func send(_ endpoint: APIEndpoint) async throws {
        let modifiedEndpoint = try await endpointWithAuthHeader(endpoint)
        try await apiService.send(modifiedEndpoint)
    }
    
    func send<T: Decodable & Sendable>(_ endpoint: APIEndpoint, as type: T.Type) async throws -> T {
        let modifiedEndpoint = try await endpointWithAuthHeader(endpoint)
        return try await apiService.send(modifiedEndpoint, as: type)
    }
    
    private func endpointWithAuthHeader(_ endpoint: APIEndpoint) async throws -> APIEndpoint {
        guard let token = try await tokenManager.ensureValidToken() else {
            throw APIError.unauthorized
        }
        return endpoint.addHeaders(["Authorization": "Profile \(token)"])
    }
}
