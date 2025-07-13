import Foundation

protocol ScoreService: Sendable {
    func getScores(types: Set<SahhaScoreType>, startDateTime: Date, endDateTime: Date) async throws -> [SahhaScore]
}

final class ScoreServiceImpl: ScoreService {
    private let api: APIService
    
    init(api: APIService) {
        self.api = api
    }
    
    func getScores(types: Set<SahhaScoreType>, startDateTime: Date, endDateTime: Date) async throws -> [SahhaScore] {
        var queryParameters = [URLQueryItem]()
        types.forEach { type in queryParameters.append(URLQueryItem(name: "types", value: type.rawValue)) }
        queryParameters.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        queryParameters.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))
        let request = APIRequest(endpoint: Constants.Endpoints.score, queryParameters: queryParameters)
        return try await api.send(request)
    }
}
