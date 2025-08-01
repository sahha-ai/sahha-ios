final class DataLogService: DataLogServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    

    func postDataLogs(_ logs: [DataLogRequest]) async throws {
        let request = APIRequest(
            endpoint: APIEndpoints.dataLog,
            method: .POST,
            body: logs,
            requiresAuth: true
        )
        try await apiClient.send(request)
    }
}
