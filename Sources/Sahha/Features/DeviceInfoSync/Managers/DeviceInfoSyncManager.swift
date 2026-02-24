final class DeviceInfoSyncManager: DeviceInfoSyncManagerProtocol, Disposable {
    private let deviceInfoBuilder: DeviceInfoBuilderProtocol
    private let deviceInfoCache: DeviceInfoSyncCacheProtocol
    private let deviceInfoService: DeviceInfoSyncServiceProtocol
    private let logger: ErrorLoggerProtocol

    private let syncTaskActor = SingleTaskActor<Void>()

    init(
        deviceInfoBuilder: DeviceInfoBuilderProtocol,
        deviceInfoCache: DeviceInfoSyncCacheProtocol,
        deviceInfoService: DeviceInfoSyncServiceProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.deviceInfoBuilder = deviceInfoBuilder
        self.deviceInfoCache = deviceInfoCache
        self.deviceInfoService = deviceInfoService
        self.logger = logger
    }

    func syncDeviceInfo() async {
        await syncTaskActor.run {
            do {
                let deviceInfo = await self.deviceInfoBuilder.build()

                if await self.deviceInfoCache.needsSync(comparedTo: deviceInfo) {
                    try await self.performSync(deviceInfo)
                    await self.deviceInfoCache.cacheDeviceInfo(deviceInfo)
                }
            } catch {
            }
        }
    }

    func forceSyncDeviceInfo() async {
        await syncTaskActor.run {
            do {
                let deviceInfo = await self.deviceInfoBuilder.build()
                try await self.performSync(deviceInfo)
                await self.deviceInfoCache.cacheDeviceInfo(deviceInfo)
            } catch {
            }
        }
    }

    private func performSync(_ deviceInfo: DeviceInfo) async throws {
        let request = DeviceInfoRequest(deviceInfo)
        try await deviceInfoService.syncDeviceInfo(request)
    }
    
    func dispose() async {
        await syncTaskActor.cancel()
    }
}
