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

            // MARK: Device Information Struct

            await container.register(DeviceInformation.self) { c in
                let provider = DeviceInformationProviderImpl(framework: settings.framework)
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

            // MARK: Device Information

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

            await container.register(DataLogProcessor.self) { c in
                let service = try await c.resolve(DataLogService.self)
                let logger = try await c.resolve(Logger.self)
                let storage = DataLogBatchStorageImpl(directory: Constants.Directories.dataLogBatches)
                let deviceInfo = try await c.resolve(DeviceInformation.self)
                let deviceId = deviceInfo.deviceId
                let uploader = DataLogUploaderImpl(service: service, deviceId: deviceId, storage: storage)
                return DataLogProcessorImpl(logger: logger, storage: storage, uploader: uploader)
            }

            // MARK: HealthKit
            
            await container.register(HKAnchorStore.self) {c in
                HKAnchorStoreImpl()
            }

            await container.register(HKManager.self) { c in
                let logger = try await c.resolve(Logger.self)
                
                let processor = try await c.resolve(DataLogProcessor.self)
                let anchorStore = try await c.resolve(HKAnchorStore.self)
                let anchorQueryHandler = HKAnchorQueryHandlerImpl(
                    anchorStore: anchorStore,
                    logger: logger,
                    processor: processor,
                    normaliser: HKSampleToDataLogRegistry.normaliser
                )
                
                let observerQueryHandler = HKObserverQueryHandlerImpl(logger: logger, anchorQueryHandler: anchorQueryHandler)
                let permissionHandler = HKPermissionHandlerImpl()
                
                let sampleQueryHandler = HKSampleQueryHandlerImpl(logger: logger)
                let statsQueryHandler = HKStatisticsQueryHandlerImpl(logger: logger)
                
                return HKManagerImpl(
                    permissionHandler: permissionHandler,
                    observerQueryHandler: observerQueryHandler,
                    sampleQueryHandler: sampleQueryHandler,
                    statsQueryHandler: statsQueryHandler
                )
            }

            // MARK: Sensors

            await container.register(SensorStore.self) { c in
                SensorStoreImpl()
            }

            await container.register(SensorManager.self) { c in
                let store = try await c.resolve(SensorStore.self)
                let hkManager = try await c.resolve(HKManager.self)
                let logger = try await c.resolve(Logger.self)
                return SensorManagerImpl(store: store, hkManager: hkManager, logger: logger)
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

            let lifecycleObserver = try await container.resolve(LifecycleObserver.self)
            let deviceInfoStore = try await container.resolve(DeviceInformationStore.self)
            let deviceInfo = try await container.resolve(DeviceInformation.self)
            let sensorManager = try await container.resolve(SensorManager.self)
            let sensorStore = try await container.resolve(SensorStore.self)
            let dataLogProcessor = try await container.resolve(DataLogProcessor.self)

            let deviceSyncHandler = DeviceInformationSyncHandler(store: deviceInfoStore, tokenManager: tokenManager)
            let resumeSensorsHandler = ResumeSensorsHandler(sensorManager: sensorManager, tokenManager: tokenManager)
            let deviceLogHandler = DeviceLogHandler(
                sensorStore: sensorStore,
                deviceInfo: deviceInfo,
                processor: dataLogProcessor,
                tokenManager: tokenManager
            )

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

    func getSensorManager() async throws -> SensorManager {
        return try await resolve(SensorManager.self)
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
