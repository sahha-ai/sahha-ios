public struct SahhaScore: Codable, Sendable {
    public struct ScoreFactor: Codable, Sendable {
        let name: String
        let value: Double
        let goal: Double
        let score: Double
        let state: String
    }

    let id: String
    let type: SahhaScoreType
    let state: String
    let score: Double
    let factors: [ScoreFactor]
    let dataSources: [String]
    let scoreDateTime: String
    let createdAtUtc: String
    let version: Int
}
