protocol DemographicCacheProtocol: Actor, Disposable {
    func getDemographic() async -> SahhaDemographic?
    func cacheDemographic(_ demographic: SahhaDemographic) async
    func needsUpdate(comparedTo demographic: SahhaDemographic) async -> Bool
}
