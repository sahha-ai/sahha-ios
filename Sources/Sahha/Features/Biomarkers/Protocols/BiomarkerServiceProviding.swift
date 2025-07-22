import Foundation

protocol BiomarkerServiceProviding: Sendable {
    func fetchBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> [SahhaBiomarker]
}
