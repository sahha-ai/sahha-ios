protocol LoggingService: Sendable {
    func postError(_ error: ErrorRequest) async throws
}

final class LoggingServiceImpl: LoggingService {
    private let api: APIService
    
    init(api: APIService) {
        self.api = api
    }
    
    func postError(_ error: ErrorRequest) async throws {
        let request = APIRequest(
            endpoint: Constants.Endpoints.error,
            method: .POST,
            body: error
        )
        try await api.send(request)
    }
}
