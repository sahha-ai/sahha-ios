import Foundation

protocol ScoreServiceProtocol: Sendable {
    func getScores(types: Set<SahhaScoreType>, startDateTime: Date, endDateTime: Date) async throws -> [SahhaScore]
}
