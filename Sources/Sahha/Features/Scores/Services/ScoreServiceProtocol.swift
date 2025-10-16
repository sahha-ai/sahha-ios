protocol ScoreServiceProtocol: Sendable {
    func fetchScores(
        types: Set<SahhaScoreType>,
        startDateTime: String,
        endDateTime: String
    ) async throws -> [SahhaScore]
}
