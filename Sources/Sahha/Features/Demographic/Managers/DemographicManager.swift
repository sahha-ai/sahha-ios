protocol DemographicManager: Sendable, Disposable {
    func getDemographic() async throws -> SahhaDemographic
    func updateDemographic(_ demographic: SahhaDemographic) async throws
}
