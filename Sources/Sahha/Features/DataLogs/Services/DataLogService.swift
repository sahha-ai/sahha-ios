import Foundation

final class DataLogService: DataLogServiceProtocol {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    // TODO: Validate against empty array?
    func postDataLogs(_ logs: [DataLog]) async throws {
        let _ = APIRequest(endpoint: Constants.Endpoints.dataLog, method: .POST, body: logs)
//        try await apiService.send(request)
        print("Posting data logs...")
    }
}
