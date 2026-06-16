import Foundation

final class BiomarkerManager: BiomarkerManagerProtocol {
    private let biomarkerService: BiomarkerServiceProtocol

    init(biomarkerService: BiomarkerServiceProtocol) {
        self.biomarkerService = biomarkerService
    }

    func getBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> String {
        guard !categories.isEmpty else {
            throw SahhaError(message: "Empty categories set is not allowed.")
        }
        guard !types.isEmpty else {
            throw SahhaError(message: "Empty types set is not allowed.")
        }
        guard startDateTime <= endDateTime else {
            throw SahhaError(message: "Start date time must be less than or equal to end date time.")
        }
        
        let response = try await biomarkerService.fetchBiomarkers(
            categories: categories,
            types: types,
            startDateTime: startDateTime.isoDateTime,
            endDateTime: endDateTime.isoDateTime
        )
        
        do {
            return try response.toJSONString()
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
