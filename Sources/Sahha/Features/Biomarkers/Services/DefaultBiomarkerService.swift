import Foundation

final class DefaultBiomarkerService: BiomarkerService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func getBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> [SahhaScore] {
        var queryParameters = [URLQueryItem]()
        categories.forEach { category in queryParameters.append(URLQueryItem(name: "categories", value: category.rawValue)) }
        types.forEach { type in queryParameters.append(URLQueryItem(name: "types", value: type.rawValue)) }
        queryParameters.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        queryParameters.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))
        
        let request = APIRequest(endpoint: APIEndpoints.biomarker, queryParameters: queryParameters, requiresAuth: true)
        return try await api.send(request)
    }
}
