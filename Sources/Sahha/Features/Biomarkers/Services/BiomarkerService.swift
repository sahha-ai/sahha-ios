import Foundation

protocol BiomarkerService: Sendable {
    func getBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> [SahhaBiomarker]
}

final class BiomarkerServiceImpl: BiomarkerService {
    private let api: APIService

    init(api: APIService) {
        self.api = api
    }

    func getBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> [SahhaBiomarker] {
        var queryParameters = [URLQueryItem]()
        categories.forEach { category in queryParameters.append(URLQueryItem(name: "categories", value: category.rawValue)) }
        types.forEach { type in queryParameters.append(URLQueryItem(name: "types", value: type.rawValue)) }
        queryParameters.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        queryParameters.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))
        let request = APIRequest(endpoint: Constants.Endpoints.biomarker, queryParameters: queryParameters)
        return try await api.send(request)
    }
}
