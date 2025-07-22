final class DefaultDemographicService: DemographicService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }
    
    func getDemographic() async throws -> SahhaDemographic {
        let request = APIRequest(
            endpoint: APIEndpoints.demographic,
            requiresAuth: true
        )
        return try await api.send(request)
    }
    
    func updateDemographic(_ demographic: SahhaDemographic) async throws {
        let request = APIRequest(
            endpoint: APIEndpoints.demographic,
            method: .PATCH,
            body: demographic,
            requiresAuth: true,
        )
        try await api.send(request)
    }
}
