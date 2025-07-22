import Foundation

final class DefaultScoreService: ScoreService {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }
    
    func getScores(types: Set<SahhaScoreType>, startDateTime: Date, endDateTime: Date) async throws -> [SahhaScore] {
        var queryParameters = [URLQueryItem]()
        types.forEach { type in queryParameters.append(URLQueryItem(name: "types", value: type.rawValue)) }
        queryParameters.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        queryParameters.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))
        
        let request = APIRequest(endpoint: APIEndpoints.biomarker, queryParameters: queryParameters, requiresAuth: true)
        return try await api.send(request)
    }
}
