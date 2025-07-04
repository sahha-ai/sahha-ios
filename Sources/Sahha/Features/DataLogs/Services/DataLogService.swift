import Foundation

protocol DataLogServiceProtocol: Sendable {
    func postDataLogs(_ logs: [DataLogRequest]) async throws
}

final class DataLogService: DataLogServiceProtocol {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    func postDataLogs(_ logs: [DataLogRequest]) async throws {
        // Don't call the API if there is no logs to send
        guard !logs.isEmpty else { return }
        
        let _ = APIRequest(endpoint: Constants.Endpoints.dataLog, method: .POST, body: logs)
//        try await apiService.send(request)
        print("Posting data logs...")
    }
}
