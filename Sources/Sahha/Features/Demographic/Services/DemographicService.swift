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
        // A profile with no demographic stored yet answers 204. That is the empty
        // state, not a failure: treating it as one stopped syncDemographic before it
        // could backfill gender and birth date from HealthKit.
        let demographic: SahhaDemographic? = try await apiClient.sendOptional(request)
        return demographic ?? SahhaDemographic()
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
