import Foundation

protocol ScoreServiceProviding: Sendable {
    func fetchScores(
        types: Set<SahhaScoreType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> [SahhaScore]
}
