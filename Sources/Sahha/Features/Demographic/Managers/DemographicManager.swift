final class DemographicManager: DemographicManagerProtocol, Disposable {
    private let demographicService: DemographicServiceProtocol
    private let cache: DemographicCacheProtocol
    private let logger: ErrorLoggerProtocol

    private let updateTaskActor = SingleThrowingTaskActor<Void>()

    init(
        demographicService: DemographicServiceProtocol,
        cache: DemographicCacheProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.demographicService = demographicService
        self.cache = cache
        self.logger = logger
    }

    func getDemographic() async throws -> SahhaDemographic {
        if let demographic = await cache.getDemographic() {
            return demographic
        }
        let remote = try await demographicService.getDemographic()
        await cache.cacheDemographic(remote)
        return remote
    }

    func updateDemographic(_ demographic: SahhaDemographic) async throws {
        try await updateTaskActor.run {
            guard await self.cache.needsUpdate(comparedTo: demographic) else { return }
            try await self.demographicService.patchDemographic(demographic)
            await self.cache.cacheDemographic(demographic)
        }
    }
    
    func dispose() async {
        await updateTaskActor.cancel()
    }
}
