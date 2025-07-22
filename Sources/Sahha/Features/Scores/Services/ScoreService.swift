import Foundation

protocol ScoreService: Sendable {
    func getScores(types: Set<SahhaScoreType>, startDateTime: Date, endDateTime: Date) async throws -> [SahhaScore]
}
