final actor DefaultDeviceInfoManager: DeviceInfoManager {
    private let deviceInfoService: DeviceInfoService
    private let collector: DeviceInfoCollector
    private let cache = DeviceInfoCache()
    
    private var syncTask: Task<Void, Error>? = nil

    init(deviceInfoService: DeviceInfoService, collector: DeviceInfoCollector) {
        self.deviceInfoService = deviceInfoService
        self.collector = collector
    }

    func sync() async throws {
        let info = await collector.collect()

        guard await cache.shouldUpdate(info) else {
            return
        }

        try await performSync(info)
    }

    func forceSync() async throws {
        let info = await collector.collect()
        try await performSync(info)
    }

    private func performSync(_ info: DeviceInformation) async throws {
        if let task = syncTask {
            return try await task.value
        }
       
        let task = Task {
            defer { syncTask = nil }
            try await deviceInfoService.updateDeviceInfo(info)
            await cache.save(info)
        }
        
        syncTask = task
        try await task.value
    }
    
    func dispose() async {
        syncTask?.cancel()
        await cache.clear()
    }
}
