import Foundation

protocol BiomarkerService: Sendable {
    func getBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> [SahhaScore]
}
