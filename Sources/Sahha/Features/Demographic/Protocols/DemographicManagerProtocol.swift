protocol DemographicManagerProtocol: Actor, DisposableAsync {
    func getDemographic() async throws -> SahhaDemographic
    func updateDemographic(_ demographic: SahhaDemographic) async throws
}
