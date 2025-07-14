import HealthKit

final actor SahhaActor {
    static let shared = SahhaActor()
    private let container = DIContainer()
    private var settings: SahhaSettings?
    private var configurationTask: Task<Void, Error>?

    private init() {}

    func configure(with settings: SahhaSettings) async throws {
        self.settings = settings

        configurationTask = Task {
            await container.reset()

            // MARK: Device Information (Core)

            await container.register(DeviceInformation.self) { _ in
                let deviceIdStore = DeviceIdStoreImpl()
                let provider = DeviceInfoProviderImpl(
                    framework: settings.framework,
                    deviceIdStore: deviceIdStore
                )
                return await provider.getDeviceInformation()
            }

            // MARK: API

            await container.register(APIService.self) { _ in
                let environment = settings.environment
                return try APISerivceImpl(environment: environment)
            }

            // MARK: Logging

            await container.register(LoggingService.self) { c in
                let api = try await c.resolve(APIService.self)
                return LoggingServiceImpl(api: api)
            }

            await container.register(Logger.self) { c in
                let service = try await c.resolve(LoggingService.self)
                let deviceInfo = try await c.resolve(DeviceInformation.self)
                return LoggerImpl(service: service, deviceInfo: deviceInfo)
            }

            // MARK: Device Information (Feature)

            await container.register(DeviceInformationService.self) { c in
                let api = try await c.resolve(APIService.self)
                return DeviceInformationServiceImpl(api: api)
            }

            await container.register(DeviceInformationStore.self) { c in
                let logger = try await c.resolve(Logger.self)
                let deviceInfo = try await c.resolve(DeviceInformation.self)
                let service = try await c.resolve(DeviceInformationService.self)
                return DeviceInformationStoreImpl(
                    logger: logger,
                    deviceInfo: deviceInfo,
                    service: service
                )
            }

            // MARK: Lifecycle

            await container.register(LifecycleObserver.self) { c in
                let logger = try await c.resolve(Logger.self)
                return LifecycleObserverImpl(logger: logger)
            }

            // MARK: Sensors

            await container.register(SensorStore.self) { _ in
                SensorStoreImpl()
            }

            // MARK: Authentication

            await container.register(AuthService.self) { c in
                let api = try await c.resolve(APIService.self)
                return AuthServiceImpl(api: api)
            }

            await container.register(TokenManager.self) { c in
                let service = try await c.resolve(AuthService.self)
                let storage = KeychainStorageImpl<TokenResponse>(account: Constants.Keychain.Token.account)
                return await TokenManagerImpl(service: service, storage: storage)
            }

            // MARK: Demographic

            await container.register(DemographicService.self) { c in
                let api = try await c.resolve(APIService.self)
                return DemographicServiceImpl(api: api)
            }

            await container.register(DemographicStore.self) { c in
                let logger = try await c.resolve(Logger.self)
                let service = try await c.resolve(DemographicService.self)
                return DemographicStoreImpl(logger: logger, service: service)
            }

            // MARK: DataLogs

            await container.register(DataLogService.self) { c in
                let api = try await c.resolve(APIService.self)
                return DataLogServiceImpl(api: api)
            }

            await container.register(DataLogBatchStorage.self) { _ in
                DataLogBatchStorageImpl(directory: Constants.Directories.dataLogBatches)
            }

            await container.register(DataLogProcessor.self) { c in
                let service = try await c.resolve(DataLogService.self)
                let logger = try await c.resolve(Logger.self)
                let storage = try await c.resolve(DataLogBatchStorage.self)
                let deviceInfo = try await c.resolve(DeviceInformation.self)
                let deviceId = deviceInfo.deviceId
                let uploader = DataLogUploaderImpl(service: service, deviceId: deviceId, storage: storage)
                return DataLogProcessorImpl(logger: logger, storage: storage, uploader: uploader)
            }

            // MARK: HealthKit

            await container.register(HKAnchorStore.self) { _ in
                HKAnchorStoreImpl()
            }

            await container.register(HKObserverQueryHandler.self) { c in
                let logger = try await c.resolve(Logger.self)
                let anchorStore = try await c.resolve(HKAnchorStore.self)
                let dataLogProcessor = try await c.resolve(DataLogProcessor.self)
                let anchorQueryHandler = HKAnchorQueryHandlerImpl(anchorStore: anchorStore)

                let eventHandler = HKObserverEventHandlerImpl(
                    anchorQueryHandler: anchorQueryHandler,
                    anchorStore: anchorStore,
                    normaliser: DataLogNormaliserRegistry.normaliser,
                    dataLogProcessor: dataLogProcessor,
                    logger: logger
                )

                return HKObserverQueryHandlerImpl(logger: logger, eventHandler: eventHandler)
            }

            await container.register(SampleProvider.self) { c in
                let authorizationManager = HKAuthorizationManagerImpl()
                let sampleQueryHandler = HKSampleQueryHandlerImpl()

                return SampleProviderImpl(
                    authorizationManager: authorizationManager,
                    sampleQueryHandler: sampleQueryHandler,
                    sampleNormaliser: SahhaSampleNormaliserRegistry.normaliser
                )
            }

            await container.register(StatsProvider.self) { c in
                let authorizationManager = HKAuthorizationManagerImpl()
                let sampleQueryHandler = HKSampleQueryHandlerImpl()
                let statsQueryHandler = HKStatisticsQueryHandlerImpl()

                let sleepStatsProvider = SleepStatsProviderImpl(
                    authorizationManager: authorizationManager,
                    sampleQueryHandler: sampleQueryHandler
                )
                let exerciseStatsProvider = ExerciseStatsProviderImpl(
                    authorizationManager: authorizationManager,
                    sampleQueryHandler: sampleQueryHandler
                )
                let quantityStatsProvider = QuantityStatsProviderImpl(
                    authorizationManager: authorizationManager,
                    statisticsQueryHandler: statsQueryHandler
                )

                return StatsProviderImpl(
                    sleepStatsProvider: sleepStatsProvider,
                    exerciseStatsProvider: exerciseStatsProvider,
                    quantityStatsProvider: quantityStatsProvider
                )
            }

            await container.register(HKManager.self) { c in
                let authorizationManager = HKAuthorizationManagerImpl()
                let sensorStore = try await c.resolve(SensorStore.self)
                let observerQueryHandler = try await c.resolve(HKObserverQueryHandler.self)
                let sampleProvider = try await c.resolve(SampleProvider.self)
                let statsProvider = try await c.resolve(StatsProvider.self)

                return HKManagerImpl(
                    authorizationManager: authorizationManager,
                    observerQueryHandler: observerQueryHandler,
                    sensorStore: sensorStore,
                    sampleProvider: sampleProvider,
                    statsProvider: statsProvider
                )
            }

            // MARK: API Interceptors

            let apiService = try await container.resolve(APIService.self)
            let tokenManager = try await container.resolve(TokenManager.self)
            let logger = try await container.resolve(Logger.self)

            let authInterceptor = AuthInterceptor(tokenManager: tokenManager)
            let errorInterceptor = ErrorInterceptor(logger: logger)

            await apiService.registerInterceptor(authInterceptor)
            await apiService.registerInterceptor(errorInterceptor)

            // MARK: Lifecycle Handlers

            await container.register(DeviceInformationSyncHandler.self) { c in
                let store = try await c.resolve(DeviceInformationStore.self)
                let tokenManager = try await c.resolve(TokenManager.self)
                return DeviceInformationSyncHandler(
                    store: store,
                    tokenManager: tokenManager
                )
            }

            await container.register(ResumeSensorsHandler.self) { c in
                let hkManager = try await c.resolve(HKManager.self)
                let tokenManager = try await c.resolve(TokenManager.self)
                return ResumeSensorsHandler(
                    hkManager: hkManager,
                    tokenManager: tokenManager
                )
            }

            await container.register(DeviceLogHandler.self) { c in
                let sensorStore = try await c.resolve(SensorStore.self)
                let deviceInfo = try await c.resolve(DeviceInformation.self)
                let processor = try await c.resolve(DataLogProcessor.self)
                let tokenManager = try await c.resolve(TokenManager.self)
                return DeviceLogHandler(
                    sensorStore: sensorStore,
                    deviceInfo: deviceInfo,
                    processor: processor,
                    tokenManager: tokenManager
                )
            }

            let lifecycleObserver = try await container.resolve(LifecycleObserver.self)
            let deviceSyncHandler = try await container.resolve(DeviceInformationSyncHandler.self)
            let resumeSensorsHandler = try await container.resolve(ResumeSensorsHandler.self)
            let deviceLogHandler = try await container.resolve(DeviceLogHandler.self)

            await lifecycleObserver.addHandler(deviceSyncHandler, for: [.didBecomeActive])
            await lifecycleObserver.addHandler(resumeSensorsHandler, for: [.didBecomeActive])
            await lifecycleObserver.addHandler(deviceLogHandler, for: Set(LifecycleEvent.allCases))
        }

        try await configurationTask?.value
        configurationTask = nil
    }

    func reset() async throws {
        guard let settings = settings else {
            throw SahhaError.notConfigured
        }
        await container.reset()
        try await configure(with: settings)
    }

    private func resolve<T: Sendable>(_ type: T.Type) async throws -> T {
        if let task = configurationTask {
            try await task.value
        }
        return try await container.resolve(type)
    }

    // MARK: Resolvers

    func getAuthService() async throws -> AuthService {
        return try await resolve(AuthService.self)
    }

    func getTokenManager() async throws -> TokenManager {
        return try await resolve(TokenManager.self)
    }

    func getDeviceInfoStore() async throws -> DeviceInformationStore {
        return try await resolve(DeviceInformationStore.self)
    }

    func getDemographicStore() async throws -> DemographicStore {
        return try await resolve(DemographicStore.self)
    }

    func getHkManager() async throws -> HKManager {
        return try await resolve(HKManager.self)
    }

    func getScoreService() async throws -> ScoreService {
        return try await resolve(ScoreService.self)
    }

    func getBiomarkerService() async throws -> BiomarkerService {
        return try await resolve(BiomarkerService.self)
    }
}
