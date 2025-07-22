final actor SahhaActor {
    static let shared = SahhaActor()

    private var settings: SahhaSettings?
    private var container: DIContainer

    private init() {
        container = DIContainer()
    }

    func configure(_ settings: SahhaSettings) async throws {

        self.settings = settings

        // MARK: Device Info
        await container.register(DeviceIdStore.self) { _ in
            DefaultDeviceIdStore()
        }
        await container.register(DeviceInfoCollector.self) { c in
            DefaultDeviceInfoCollector(
                framework: settings.framework,
                deviceIdStore: try await c.resolve(DeviceIdStore.self)
            )
        }

        // MARK: Lifecycle
        await container.register(LifecycleObserver.self) { _ in
            DefaultLifecycleObserver()
        }

        // MARK: API
        await container.register(APIClient.self) { _ in
            try DefaultAPIClient(baseURL: settings.environment.baseURL)
        }

        // MARK: Logging
        await container.register(Logger.self) { c in
            DefaultLogger(
                api: try await c.resolve(APIClient.self),
                deviceInfo: try await c.resolve(DeviceInfoCollector.self).collect()
            )
        }
        await container.register(LoggingInterceptor.self) { c in
            LoggingInterceptor(logger: try await c.resolve(Logger.self))
        }

        // MARK: Auth
        await container.register(AuthService.self) { c in
            DefaultAuthService(api: try await c.resolve(APIClient.self))
        }
        await container.register(TokenStore.self) { _ in
            DefaultTokenStore()
        }
        await container.register(TokenProvider.self) { c in
            DefaultTokenManager(
                authService: try await c.resolve(AuthService.self),
                tokenStore: try await c.resolve(TokenStore.self)
            )
        }
        await container.register(AuthManager.self) { c in
            DefaultAuthManager(
                authService: try await c.resolve(AuthService.self),
                tokenProvider: try await c.resolve(TokenProvider.self)
            )
        }
        await container.register(AuthInterceptor.self) { c in
            AuthInterceptor(tokenProvider: try await c.resolve(TokenProvider.self))
        }

        // MARK: Device
        await container.register(DeviceInfoService.self) { c in
            DefaultDeviceInfoService(api: try await c.resolve(APIClient.self))
        }
        await container.register(DeviceInfoManager.self) { c in
            DefaultDeviceInfoManager(
                deviceInfoService: try await c.resolve(DeviceInfoService.self),
                collector: try await c.resolve(DeviceInfoCollector.self)
            )
        }

        // MARK: DataLog Pipeline
        await container.register(DataLogRequestFactory.self) { c in
            DefaultDataLogRequestFactory(deviceIdStore: try await c.resolve(DeviceIdStore.self))
        }
        await container.register(DataLogBatchStorage.self) { c in
            DataLogBatchStorage(
                directory: Directories.dataLogBatchDirectory,
                logger: try await c.resolve(Logger.self)
            )
        }
        await container.register(DataLogUploader.self) { c in
            DataLogUploader(
                api: try await c.resolve(APIClient.self),
                requestFactory: try await c.resolve(DataLogRequestFactory.self),
                storage: try await c.resolve(DataLogBatchStorage.self),
                logger: try await c.resolve(Logger.self)
            )
        }
        await container.register(DataLogProcessor.self) { c in
            DataLogProcessor(
                storage: try await c.resolve(DataLogBatchStorage.self),
                uploader: try await c.resolve(DataLogUploader.self),
                logger: try await c.resolve(Logger.self)
            )
        }

        // MARK: HealthKit
        await container.register(HKPermissionManager.self) { _ in
            DefaultHKPermissionManager()
        }
        await container.register(HKObserverManager.self) { c in
            DefaultHKObserverManager()
        }
        await container.register(HKAnchorStore.self) { _ in
            UserDefaultsHKAnchorStore()
        }
        await container.register(DataLogFetcher.self) { c in
            DataLogFetcher(
                anchorStore: try await c.resolve(HKAnchorStore.self),
                processor: try await c.resolve(DataLogProcessor.self),
                logger: try await c.resolve(Logger.self)
            )
        }
        await container.register(SamplesFetcher.self) { c in
            SamplesFetcher()
        }
        await container.register(StatsFetcher.self) { c in
            StatsFetcher()
        }

        // MARK: Sensors
        await container.register(SensorStore.self) { _ in
            UserDefaultsSensorStore()
        }
        await container.register(SensorManager.self) { c in
            DefaultSensorManager(
                sensorStore: try await c.resolve(SensorStore.self),
                observerManager: try await c.resolve(HKObserverManager.self),
                permissionManager: try await c.resolve(HKPermissionManager.self),
                dataLogFetcher: try await c.resolve(DataLogFetcher.self),
                samplesFetcher: try await c.resolve(SamplesFetcher.self),
                statsFetcher: try await c.resolve(StatsFetcher.self),
                logger: try await c.resolve(Logger.self)
            )
        }

        // MARK: Biomarker
        await container.register(BiomarkerService.self) { c in
            DefaultBiomarkerService(api: try await c.resolve(APIClient.self))
        }

        // MARK: Score
        await container.register(ScoreService.self) { c in
            DefaultScoreService(api: try await c.resolve(APIClient.self))
        }

        // MARK: Demographic
        await container.register(DemographicService.self) { c in
            DefaultDemographicService(api: try await c.resolve(APIClient.self))
        }
        await container.register(DemographicManager.self) { c in
            DefaultDemographicManager(demographicService: try await c.resolve(DemographicService.self))
        }

        //MARK: Lifecycle Listeners
        await container.register(DeviceLogListener.self) { c in
            DeviceLogListener(
                collector: try await c.resolve(DeviceInfoCollector.self),
                sensorStore: try await c.resolve(SensorStore.self),
                processor: try await c.resolve(DataLogProcessor.self),
            )
        }
        await container.register(DeviceInfoSyncListener.self) { c in
            DeviceInfoSyncListener(
                manager: try await c.resolve(DeviceInfoManager.self)
            )
        }

        // MARK: Register Interceptors
        let api = try await container.resolve(APIClient.self)
        let authInterceptor = try await container.resolve(AuthInterceptor.self)
        let loggingInterceptor = try await container.resolve(LoggingInterceptor.self)

        await api.registerInterceptor(authInterceptor)
        await api.registerInterceptor(loggingInterceptor)

        // Run authenticated services if valid token
        let tokenProvider = try await container.resolve(TokenProvider.self)

        if (try? await tokenProvider.validProfileToken()) != nil {
            try await onAuthenticated()
        }
    }

    func onAuthenticated() async throws {
        // Register lifecycle listeners
        let lifecycleObserver = try await container.resolve(LifecycleObserver.self)
        let deviceLogListener = try await container.resolve(DeviceLogListener.self)
        let deviceInfoSyncListener = try await container.resolve(DeviceInfoSyncListener.self)

        await lifecycleObserver.registerListener(deviceLogListener)
        await lifecycleObserver.registerListener(deviceInfoSyncListener)

        // Force sync device info
        let deviceInfoManager = try await container.resolve(DeviceInfoManager.self)

        do {
            try await deviceInfoManager.forceSync()
        } catch {
            print("Failed to force sync device info: \(error)")
        }

        // Resume sensors
        let sensorManager = try await container.resolve(SensorManager.self)

        do {
            try await sensorManager.resumeSensors()
        } catch {
            print("Failed to resume sensors: \(error)")
        }
    }

    func resetContainer() async throws {
        guard let settings = settings else {
            throw SahhaError.notConfigured
        }
        await container.reset()
        try await configure(settings)
    }

    private func resolve<T: Sendable>(_ type: T.Type) async throws -> T {
        try await container.resolve(type)
    }

    // MARK: Convenience functions

    func getAuthManager() async throws -> AuthManager {
        try await resolve(AuthManager.self)
    }

    func getDemographicManager() async throws -> DemographicManager {
        try await resolve(DemographicManager.self)
    }

    func getSensorManager() async throws -> SensorManager {
        try await resolve(SensorManager.self)
    }

    func getScoreService() async throws -> ScoreService {
        try await resolve(ScoreService.self)
    }

    func getBiomarkerService() async throws -> BiomarkerService {
        try await resolve(BiomarkerService.self)
    }
}
