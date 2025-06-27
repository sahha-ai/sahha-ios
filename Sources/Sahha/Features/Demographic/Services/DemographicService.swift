final class DemographicService: DemographicServiceProtocol {
    private let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }

    func getDemographic() async throws -> SahhaDemographic {
        let request = APIRequest(endpoint: Constants.Endpoints.demographic)
        return try await apiService.send(request)
    }

    func updateDemographic(_ demographic: SahhaDemographic) async throws {
        let request = APIRequest(
            endpoint: Constants.Endpoints.demographic,
            method: .PATCH,
            body: demographic
        )
        try await apiService.send(request)
    }
}
