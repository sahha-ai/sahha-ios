import Foundation

final class DemographicService: DemographicServiceProviding {
    private let cache: DemographicCaching
    private let apiClient: APIClientProviding
    private let ttl: TimeInterval

    init(
        cache: DemographicCaching,
        apiClient: APIClientProviding,
        ttl: TimeInterval = .minutes(15)
    ) {
        self.cache = cache
        self.apiClient = apiClient
        self.ttl = ttl
    }

    func getDemographic() async throws -> SahhaDemographic {
        // Return in-memory if valid
        if await cache.isValid(ttl: ttl), let demographic = await cache.get() {
            return demographic
        }
        // Otherwise, fetch from API and update caches
        let demographic: SahhaDemographic = try await apiClient.send(.getDemographic())
        await cache.set(demographic)
        return demographic
    }

    func updateDemographic(_ demographic: SahhaDemographic) async throws {
        try await apiClient.send(.updateDemographic(demographic))
        await cache.set(demographic)
    }
}
