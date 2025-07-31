final class ErrorLoggingService: ErrorLoggingServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    func postError(_ error: ErrorLogRequest) async throws {
        let request = APIRequest(
            endpoint: APIEndpoints.error,
            method: .POST,
            body: error
        )
        // TODO: Add this back in after testing
//        try await apiClient.send(request)
    }
}
