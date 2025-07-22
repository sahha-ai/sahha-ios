public struct SahhaScore: Codable, Sendable {
    let id: String
    let type: SahhaScoreType
    let state: String
    let score: Double
    let factors: [SahhaScoreFactor]
    let dataSources: [String]
    let scoreDateTime: String
    let createdAtUtc: String
    let version: Int
}
