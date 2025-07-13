protocol DemographicService: Sendable {
    func getDemographic() async throws -> SahhaDemographic
    func updateDemographic(_ demographic: SahhaDemographic) async throws
}

final class DemographicServiceImpl: DemographicService {
    private let api: APIService

    init(api: APIService) {
        self.api = api
    }

    func getDemographic() async throws -> SahhaDemographic {
        let request = APIRequest(endpoint: Constants.Endpoints.demographic)
        return try await api.send(request)
    }

    func updateDemographic(_ demographic: SahhaDemographic) async throws {
        let request = APIRequest(
            endpoint: Constants.Endpoints.demographic,
            method: .PATCH,
            body: demographic
        )
        try await api.send(request)
    }
}
