import Foundation

protocol ScoreManagerProtocol: Sendable {
    func getScores(
        types: Set<SahhaScoreType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> String
}
