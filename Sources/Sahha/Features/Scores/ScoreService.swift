import Foundation

protocol ScoreServiceProtocol: Actor {
    func getScores(types: Set<String>, startDateTime: Date, endDateTime: Date) async throws -> [ScoreResponse]
}

actor ScoreService: ScoreServiceProtocol {
    private let apiService: SecureAPIServiceProtocol
    
    init(apiService: SecureAPIServiceProtocol) {
        self.apiService = apiService
    }
    
    func getScores(types: Set<String>, startDateTime: Date, endDateTime: Date) async throws -> [ScoreResponse] {
        guard !types.isEmpty else {
            throw ValidationError.emptyCollection(collection: "Types")
        }
        guard startDateTime <= endDateTime else {
            throw ValidationError.invalidDateRange
        }
        
        let endpoint = GetScoresEndpoint(types: types, startDateTime: startDateTime, endDateTime: endDateTime)
        return try await apiService.send(endpoint, as: [ScoreResponse].self)
    }
}
