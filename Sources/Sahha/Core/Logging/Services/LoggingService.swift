protocol LoggingServiceProtocol: Sendable {
    func postError(_ error: ErrorRequest) async
}

final class LoggingService: LoggingServiceProtocol {
    private let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }

    func postError(_ error: ErrorRequest) async {
        let request = APIRequest(
            endpoint: Constants.Endpoints.error,
            method: .POST,
            body: error
        )
        try? await apiService.send(request)
    }
}
