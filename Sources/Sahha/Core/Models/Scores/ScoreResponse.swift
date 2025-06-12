struct ScoreResponse: Codable {
    struct Factor: Codable {
        let name: String
        let value: Double
        let goal: Double
        let score: Double
        let state: String
    }

    let id: String
    let type: String
    let state: String
    let score: Double
    let factors: [Factor]
    let dataSources: [String]
    let scoreDateTime: String
    let createdAtUtc: String
    let version: Int
}
