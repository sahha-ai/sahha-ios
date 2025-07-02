import Foundation

final class ScoreService: ScoreServiceProtocol{
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    
    func getScores(types: Set<SahhaScoreType>, startDateTime: Date, endDateTime: Date) async throws -> [SahhaScore] {
        guard !types.isEmpty else {
            throw ValidationError.emptyCollection(collection: "types")
        }
        guard startDateTime <= endDateTime else {
            throw ValidationError.invalidDateRange
        }
        
        var queryParameters = [URLQueryItem]()
        types.forEach { type in queryParameters.append(URLQueryItem(name: "types", value: type.rawValue)) }
        queryParameters.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        queryParameters.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))
        
        let request = APIRequest(endpoint: Constants.Endpoints.score, queryParameters: queryParameters)
        return try await apiService.send(request)
    }
}
