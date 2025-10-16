protocol BiomarkerServiceProtocol: Sendable {
    func fetchBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: String,
        endDateTime: String
    ) async throws -> [SahhaBiomarker]
}
