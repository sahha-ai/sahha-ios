import Foundation

final class DataLogService: DataLogServiceProtocol {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    // TODO: Validate against empty array?
    func postDataLogs(_ logs: [DataLog]) async throws {
        let request = APIRequest(endpoint: "v1/profile/data/log", method: .POST, body: logs)
//        try await apiService.request(request)
        print("Posting data logs...")
    }
}
