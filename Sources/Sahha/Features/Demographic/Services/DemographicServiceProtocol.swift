protocol DemographicServiceProtocol: Sendable {
    func getDemographic() async throws -> SahhaDemographic
    func patchDemographic(_ demographic: SahhaDemographic) async throws
}
