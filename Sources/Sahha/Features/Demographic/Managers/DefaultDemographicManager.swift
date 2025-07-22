final class DefaultDemographicManager: DemographicManager {
    private let demographicService: DemographicService
    private let cache = DemographicCache()

    init(demographicService: DemographicService) {
        self.demographicService = demographicService
    }
    
    func getDemographic() async throws -> SahhaDemographic {
        if let cached = await cache.load() {
            return cached
        }
        let demographic = try await demographicService.getDemographic()
        await cache.save(demographic)
        return demographic
    }
    
    func updateDemographic(_ demographic: SahhaDemographic) async throws {
        guard await cache.shouldUpdate(demographic) else { return }
        try await demographicService.updateDemographic(demographic)
        await cache.save(demographic)
    }
    
    func dispose() async {
        await cache.clear()
    }
}
