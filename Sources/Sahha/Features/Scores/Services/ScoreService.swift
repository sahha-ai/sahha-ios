import Foundation

final class ScoreService: ScoreServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    func fetchScores(
        types: Set<SahhaScoreType>,
        startDateTime: String,
        endDateTime: String
    ) async throws -> [SahhaScore] {
        var queryParameters = [URLQueryItem]()
        types.forEach { type in queryParameters.append(URLQueryItem(name: "types", value: type.rawValue)) }
        queryParameters.append(URLQueryItem(name: "startDateTime", value: startDateTime))
        queryParameters.append(URLQueryItem(name: "endDateTime", value: endDateTime))
        
        let request = APIRequest(
            endpoint: APIEndpoints.score,
            queryParameters: queryParameters,
            requiresAuth: true
        )
        return try await apiClient.send(request)
    }
}
