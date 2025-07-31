final class DataLogService: DataLogServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    // TODO: Uncomment and remove sleep after testing
    func postDataLogs(_ logs: [DataLogRequest]) async throws {
//        let request = APIRequest(
//            endpoint: APIEndpoints.dataLog,
//            method: .POST,
//            body: logs
//        )
        /// simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000)
//        try await apiClient.send(request)
    }
}
