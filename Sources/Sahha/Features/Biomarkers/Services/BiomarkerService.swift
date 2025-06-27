import Foundation

final class BiomarkerService: BiomarkerServiceProtocol {
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    func getBiomarkers(categories: Set<SahhaBiomarkerCategory>, types: Set<SahhaBiomarkerType>, startDateTime: Date, endDateTime: Date) async throws -> [SahhaBiomarker] {
        guard !categories.isEmpty else {
            throw ValidationError.emptyCollection(collection: "Categories")
        }
        guard !types.isEmpty else {
            throw ValidationError.emptyCollection(collection: "Types")
        }
        guard startDateTime <= endDateTime else {
            throw ValidationError.invalidDateRange
        }
        
        var queryParameters = [URLQueryItem]()
        categories.forEach { category in queryParameters.append(URLQueryItem(name: "categories", value: category.rawValue)) }
        types.forEach { type in queryParameters.append(URLQueryItem(name: "types", value: type.rawValue)) }
        queryParameters.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        queryParameters.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))
        
        let request = APIRequest(endpoint: Constants.Endpoints.biomarker, queryParameters: queryParameters)
        return try await apiService.send(request)
    }
}
