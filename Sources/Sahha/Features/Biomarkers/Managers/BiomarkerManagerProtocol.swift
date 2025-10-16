import Foundation

protocol BiomarkerManagerProtocol: Sendable {
    func getBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: Date,
        endDateTime: Date
    ) async throws -> String
}
