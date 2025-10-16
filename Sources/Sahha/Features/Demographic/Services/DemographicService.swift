final class DemographicService: DemographicServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    func getDemographic() async throws -> SahhaDemographic {
        let request = APIRequest(
            endpoint: APIEndpoints.demographic,
            requiresAuth: true
        )
       return try await apiClient.send(request)
    }
    
    func patchDemographic(_ demographic: SahhaDemographic) async throws {
        let request = APIRequest(
            endpoint: APIEndpoints.demographic,
            method: .PATCH,
            body: demographic,
            requiresAuth: true
        )
        try await apiClient.send(request)
    }
}
