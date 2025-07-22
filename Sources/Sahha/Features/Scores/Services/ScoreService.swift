import Foundation

final class ScoreService: ScoreServiceProviding {

    private let apiClient: APIClientProviding

    init(apiClient: APIClientProviding) {
        self.apiClient = apiClient
    }

    func fetchScores(
        types: Set<SahhaScoreType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> [SahhaScore] {
        try await apiClient.send(.getScores(types: types, startDateTime: startDateTime, endDateTime: endDateTime))
    }
}
