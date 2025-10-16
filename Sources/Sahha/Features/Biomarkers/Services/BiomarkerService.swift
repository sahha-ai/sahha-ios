import Foundation

final class BiomarkerService: BiomarkerServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    func fetchBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: String,
        endDateTime: String
    ) async throws -> [SahhaBiomarker] {
        var queryParameters = [URLQueryItem]()
        categories.forEach { category in queryParameters.append(URLQueryItem(name: "categories", value: category.rawValue)) }
        types.forEach { type in queryParameters.append(URLQueryItem(name: "types", value: type.rawValue)) }
        queryParameters.append(URLQueryItem(name: "startDateTime", value: startDateTime))
        queryParameters.append(URLQueryItem(name: "endDateTime", value: endDateTime))
        
        let request = APIRequest(
            endpoint: APIEndpoints.biomarker,
            queryParameters: queryParameters,
            requiresAuth: true
        )
        return try await apiClient.send(request)
    }
}
