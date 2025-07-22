import Foundation

final actor DeviceInfoSyncService: DeviceInfoSyncing {
    private let collector: DeviceInfoCollecting
    private let cache: DeviceInfoCaching
    private let apiClient: APIClientProviding
    private let ttl: TimeInterval

    private var syncTask: Task<Void, Error>?

    init(
        collector: DeviceInfoCollecting,
        cache: DeviceInfoCaching,
        apiClient: APIClientProviding,
        ttl: TimeInterval = .hours(1)
    ) {
        self.collector = collector
        self.cache = cache
        self.apiClient = apiClient
        self.ttl = ttl
    }

    /// Sync only if the payload has changed since lastFetch
    func sync() async throws {
        let info = try await collector.collect()
        if await cache.isValid(ttl: ttl),
            await cache.needsSync(with: info)
        {
            // Cache is valid and data unchanged
            return
        }

        try await performSync(info)
        await cache.set(info)
    }

    /// Always push current info regardless of hash
    func forceSync() async throws {
        let info = try await collector.collect()
        try await performSync(info)
        await cache.set(info)
    }

    private func performSync(_ info: DeviceInformation) async throws {
        if let task = syncTask {
            do { try await task.value } catch is CancellationError { return }
            return
        }
        defer { syncTask = nil }
        syncTask = Task {
            try await apiClient.send(.updateDeviceInfo(info))
        }
        do { try await syncTask?.value } catch is CancellationError { return }
    }

    func dispose() async {
        syncTask?.cancel()
    }
}
