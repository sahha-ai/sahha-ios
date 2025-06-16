import Foundation

protocol DemographicServiceProtocol: Actor {
    func getDemographic() async throws -> DemographicResponse
    func updateDemographic(_ demographic: DemographicRequest) async throws
}

actor DemographicService: DemographicServiceProtocol {
    private let apiService: SecureAPIServiceProtocol
    
    init(apiService: SecureAPIServiceProtocol) {
        self.apiService = apiService
    }
    
    func getDemographic() async throws -> DemographicResponse {
        let endpoint = GetDemographicEndpoint()
        return try await apiService.send(endpoint, as: DemographicResponse.self)
    }
    
    func updateDemographic(_ request: DemographicRequest) async throws {
        let endpoint = PatchDemographicEndpoint(request: request)
        try await apiService.send(endpoint)
    }
}
