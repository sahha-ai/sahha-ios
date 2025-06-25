final class DemographicService: DemographicServiceProtocol {
    private let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }

    func getDemographic() async throws -> SahhaDemographic {
        let request = APIRequest(endpoint: "v1/profile/demographic")
        return try await apiService.request(request)
    }

    func updateDemographic(_ demographic: SahhaDemographic) async throws {
        let request = APIRequest(
            endpoint: "v1/profile/demographic",
            method: .PATCH,
            body: demographic
        )
        try await apiService.request(request)
    }
}
