import Foundation

final class BiomarkerService: BiomarkerServiceProviding {
    private let apiClient: APIClientProviding

    init(apiClient: APIClientProviding) {
        self.apiClient = apiClient
    }

    func fetchBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> [SahhaBiomarker] {
        try await apiClient.send(.getBiomarkers(categories: categories, types: types, startDateTime: startDateTime, endDateTime: endDateTime))
    }
}
