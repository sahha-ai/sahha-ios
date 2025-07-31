import HealthKit

final class DemographicManager: DemographicManagerProtocol, Disposable {
    private let demographicService: DemographicServiceProtocol
    private let sensorStore: SensorStoreProtocol
    private let cache: DemographicCacheProtocol
    private let logger: ErrorLoggerProtocol

    private let updateTaskActor = SingleThrowingTaskActor<Void>()

    init(
        demographicService: DemographicServiceProtocol,
        sensorStore: SensorStoreProtocol,
        cache: DemographicCacheProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.demographicService = demographicService
        self.sensorStore = sensorStore
        self.cache = cache
        self.logger = logger
    }

    func getDemographic() async throws -> SahhaDemographic {
        if let demographic = await cache.getDemographic() {
            return demographic
        }
        return try await demographicService.getDemographic()
    }

    func updateDemographic(_ demographic: SahhaDemographic) async throws {
        if await cache.needsUpdate(comparedTo: demographic) { return }
        try await updateTaskActor.run {
            try await self.demographicService.patchDemographic(demographic)
            await self.cache.cacheDemographic(demographic)
        }
    }
    
    func dispose() async {
        await updateTaskActor.cancel()
    }
}
