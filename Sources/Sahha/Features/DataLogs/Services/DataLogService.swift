protocol DataLogService: Sendable {
    func postDataLogs(_ logs: [DataLogRequest]) async throws
}

final class DataLogServiceImpl: DataLogService {
    private let api: APIService
    
    init(api: APIService) {
        self.api = api
    }
    
    func postDataLogs(_ logs: [DataLogRequest]) async throws {
        guard !logs.isEmpty else { return }
        
        let _ = APIRequest(endpoint: Constants.Endpoints.dataLog, method: .POST, body: logs)
//        try await api.send(request)
        print("Simulated successful post of \(logs.count) data logs")
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}
