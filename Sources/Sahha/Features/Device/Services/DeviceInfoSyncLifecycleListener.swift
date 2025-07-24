final actor DeviceInfoSyncLifecycleListener: LifecycleListener {
    private let tokenStore: TokenStoring
    private let syncService: DeviceInfoSyncing
    private let logger: ErrorLogger

    init(tokenStore: TokenStoring, syncService: DeviceInfoSyncing, logger: ErrorLogger) {
        self.tokenStore = tokenStore
        self.syncService = syncService
        self.logger = logger
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        guard event == .app_resume || event == .app_foreground,
            let token = try? await tokenStore.profileToken(),
            token.notEmpty
        else { return }

        do {
            try await syncService.sync()
        } catch {
            logger.sdkError("Failed to sync device info", error: error)
        }
    }
}
