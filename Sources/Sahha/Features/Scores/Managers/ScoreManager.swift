import Foundation

final class ScoreManager: ScoreManagerProtocol {
    private let scoreService: ScoreServiceProtocol

    init(scoreService: ScoreServiceProtocol) {
        self.scoreService = scoreService
    }

    func getScores(
        types: Set<SahhaScoreType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> String {
        guard !types.isEmpty else {
            throw SahhaError(message: "Empty types set is not allowed.")
        }
        guard startDateTime < endDateTime else {
            throw SahhaError(message: "Start date time must be less than end date time.")
        }
        
        let response = try await scoreService.fetchScores(
            types: types,
            startDateTime: startDateTime.isoDate,
            endDateTime: endDateTime.isoDate
        )
        
        do {
            return try response.toDataWrappedJSONString()
        } catch {
            let message: String
            if let encodingError = error as? EncodingError,
                case let .invalidValue(_, context) = encodingError
            {
                message = context.debugDescription
            } else {
                message = error.localizedDescription
            }
            throw SahhaError(message: message, error: error)
        }
    }
}
