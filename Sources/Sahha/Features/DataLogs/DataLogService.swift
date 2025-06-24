import Foundation

protocol DataLogServiceProtocol: Actor {
    func postDataLogs(_ request: [DataLogRequest]) async throws
}

actor DataLogService: DataLogServiceProtocol {
    private let apiService: SecureAPIServiceProtocol
    
    init(apiService: SecureAPIServiceProtocol) {
        self.apiService = apiService
    }
    
    func postDataLogs(_ request: [DataLogRequest]) async throws {
        let endpoint = PostDataLogsEndpoint(request: request)
        return try await apiService.send(endpoint)
    }
}
