final actor SahhaActor {
    static let shared = SahhaActor()

    private var settings: SahhaSettings?
    private var container: DIContainer?

    private var configurationTask: Task<Void, Error>?

    private init() {}
    
    // MARK: Configure

    func configure(with settings: SahhaSettings) async throws {
        configurationTask = Task {
            defer { self.configurationTask = nil }
            
            self.settings = settings
            let container = DIContainer()
            
            // MARK: Device Info

            await container.register(DeviceIdStoring.self) { _ in
                KeychainDeviceIdStorage()
            }
            await container.register(DeviceInfoCollecting.self) { container in
                DeviceInfoCollector(
                    deviceIdStore: try await container.resolve(DeviceIdStoring.self),
                    sdkId: settings.framework.rawValue
                )
            }
            
            // MARK: Lifecycle

            await container.register(LifecycleObserving.self) { _ in
                LifecycleObserver()
            }
            
            // MARK: API Client

            await container.register(APIClientProviding.self) { _ in
                APIClient(baseURL: settings.environment.baseURL)
            }
            
            // MARK: Logging

            await container.register(ErrorLogger.self) { container in
                ErrorLoggingService(
                    apiClient: try await container.resolve(APIClientProviding.self),
                    collector: try await container.resolve(DeviceInfoCollecting.self)
                )
            }
            await container.register(ErrorLogIntercepting.self) { container in
                ErrorLogInterceptor(
                    logger: try await container.resolve(ErrorLogger.self)
                )
            }
            
            // MARK: Auth

            await container.register(TokenStoring.self) { _ in
                KeychainTokenStorage()
            }
            await container.register(AuthServiceProviding.self) { container in
                AuthService(
                    apiClient: try await container.resolve(APIClientProviding.self),
                    tokenStore: try await container.resolve(TokenStoring.self),
                )
            }
            await container.register(AuthIntercepting.self) { container in
                AuthInterceptor(
                    authService: try await container.resolve(AuthServiceProviding.self)
                )
            }
            
            // MARK: Biomarkers
            
            await container.register(BiomarkerServiceProviding.self) { container in
                BiomarkerService(
                    apiClient: try await container.resolve(APIClientProviding.self)
                )
            }
                        
            // MARK: Scores

            await container.register(ScoreServiceProviding.self) { container in
                ScoreService(
                    apiClient: try await container.resolve(APIClientProviding.self)
                )
            }
                        
            // MARK: Demographic

            await container.register(DemographicCaching.self) { container in
                    UserDefaultsDemographicCache(
                        logger: try await container.resolve(ErrorLogger.self)
                    )
            }
            await container.register(DemographicServiceProviding.self) { container in
                DemographicService(
                    cache: try await container.resolve(DemographicCaching.self),
                    apiClient: try await container.resolve(APIClientProviding.self),
                )
            }
            
            // MARK: DataLog Pipeline

            await container.register(DataLogBatchStoring.self) { _ in
                try await FileManagerDataLogBatchStorage(
                    storage: FileManagerStorage(directory: SahhaDirectories.batches)
                )
            }
            await container.register(DataLogRequestMapping.self) { container in
                DataLogRequestFactory(
                    deviceIdStore: try await container.resolve(DeviceIdStoring.self)
                )
            }
            await container.register(DataLogUploading.self) { container in
                DataLogUploader(
                    apiClient: try await container.resolve(APIClientProviding.self),
                    batchStorage: try await container.resolve(DataLogBatchStoring.self),
                    requestFactory: try await container.resolve(DataLogRequestMapping.self),
                    logger: try await container.resolve(ErrorLogger.self)
                )
            }
            await container.register(DataLogPipelineProviding.self) { container in
                DataLogPipeline(
                    batchStorage: try await container.resolve(DataLogBatchStoring.self),
                    uploader: try await container.resolve(DataLogUploading.self)
                )
            }
            
            // MARK: HealthKit

            await container.register(HKPermissionsProviding.self) { _ in
                HKPermissionsService()
            }
            await container.register(HKObserverProviding.self) { container in
                HKObserverService(
                    logger: try await container.resolve(ErrorLogger.self)
                )
            }
            await container.register(HKAnchorStoring.self) { _ in
                UserDefaultsHKAnchorStorage()
            }
            await container.register(HKDataLogFetching.self) { container in
                HKDataLogFetcher(
                    observer: try await container.resolve(HKObserverProviding.self),
                    anchorStore: try await container.resolve(HKAnchorStoring.self),
                    pipeline: try await container.resolve(DataLogPipelineProviding.self),
                    permissions: try await container.resolve(HKPermissionsProviding.self),
                    logger: try await container.resolve(ErrorLogger.self)
                )
            }
            await container.register(HKSahhaSampleFetching.self) { container in
                HKSahhaSampleFetcher(
                    permissions: try await container.resolve(HKPermissionsProviding.self),
                )
            }
            await container.register(HKSahhaStatsFetching.self) { container in
                HKSahhaStatsFetcher(
                    permissions: try await container.resolve(HKPermissionsProviding.self),
                )
            }
            await container.register(HealthKitProviding.self) { container in
                HealthKitService(
                    permissions: try await container.resolve(HKPermissionsProviding.self),
                    dataLogFetcher: try await container.resolve(HKDataLogFetching.self),
                    sahhaSampleFetcher: try await container.resolve(HKSahhaSampleFetching.self),
                    sahhaStatsFetcher: try await container.resolve(HKSahhaStatsFetching.self),
                    logger: try await container.resolve(ErrorLogger.self)
                )
            }
            
            // MARK: Sensors

            await container.register(SensorStoring.self) { container in
                UserDefaultsSensorStorage(
                    logger: try await container.resolve(ErrorLogger.self)
                )
            }
            await container.register(SensorManaging.self) { container in
                SensorManager(
                    sensorStore: try await container.resolve(SensorStoring.self),
                    healthKitService: try await container.resolve(HealthKitProviding.self)
                )
            }

            // MARK: Device

            await container.register(DeviceInfoCaching.self) { container in
                UserDefaultsDeviceInfoCache(
                    logger: try await container.resolve(ErrorLogger.self)
                )
            }
            await container.register(DeviceInfoSyncing.self) { container in
                DeviceInfoSyncService(
                    collector: try await container.resolve(DeviceInfoCollecting.self),
                    cache: try await container.resolve(DeviceInfoCaching.self),
                    apiClient: try await container.resolve(APIClientProviding.self),
                )
            }
            await container.register(DeviceInfoSyncLifecycleListener.self) { container in
                DeviceInfoSyncLifecycleListener(
                    tokenStore: try await container.resolve(TokenStoring.self),
                    syncService: try await container.resolve(DeviceInfoSyncing.self),
                    logger: try await container.resolve(ErrorLogger.self)
                )
            }
            await container.register(DeviceLogService.self) { container in
                DeviceLogService(
                    collector: try await container.resolve(DeviceInfoCollecting.self),
                    sensorStore: try await container.resolve(SensorStoring.self),
                    pipeline: try await container.resolve(DataLogPipelineProviding.self),
                    logger: try await container.resolve(ErrorLogger.self)
                )
            }
            
            // MARK: API Interceptors
            
            let apiClient = try await container.resolve(APIClientProviding.self)
            let authInterceptor = try await container.resolve(AuthIntercepting.self)
            await apiClient.registerInterceptor(authInterceptor)
            let errorLogInterceptor = try await container.resolve(ErrorLogIntercepting.self)
            await apiClient.registerInterceptor(errorLogInterceptor)

            self.container = container
        }
        
        try await configurationTask?.value
    }
    
    // MARK: Authenticated Services
    
    func startAuthenticatedServices() async throws {
        // DeviceLog Listener
        let deviceLogService = try await resolve(DeviceLogService.self)
        let lifecycleObserver = try await resolve(LifecycleObserving.self)
        await lifecycleObserver.registerListener(deviceLogService)

        // DeviceSync Listener
        let deviceSyncLifecycleListener = try await resolve(DeviceInfoSyncLifecycleListener.self)
        await lifecycleObserver.registerListener(deviceSyncLifecycleListener)

        // Upload persisted batch files
        let dataLogUploader = try await resolve(DataLogUploading.self)
        await dataLogUploader.uploadPendingBatches()
        
        // Resume Sensors
        let sensorManager = try await resolve(SensorManaging.self)
        try await sensorManager.resumeSensors()

        // Force Sync Device Info
        let deviceInfoSyncService = try await resolve(DeviceInfoSyncing.self)
        try await deviceInfoSyncService.forceSync()
    }
    
    func startAuthenticatedServicesIfTokenPresent() async throws {
        guard await isAuthenticated() else { return }
        try await startAuthenticatedServices()
    }
    
    private func isAuthenticated() async -> Bool {
        let authService = try? await resolve(AuthServiceProviding.self)
        if let profileToken = try? await authService?.validProfileToken() {
            return profileToken.notEmpty
        }
        return false
    }
    
    // MARK: Reset Container
    
    func resetContainer() async throws {
        guard let settings else {
            throw SahhaError.notConfigured
        }
        await container?.reset()
        container = nil
        try await configure(with: settings)
    }

    // MARK: Resolvers

    private func resolve<T: Sendable>(_ type: T.Type) async throws -> T {
        if let task = configurationTask {
            try await task.value
        }
        if let container = container {
            return try await container.resolve(type)
        } else {
            throw SahhaError.notConfigured
        }
    }
    
    func getAuthService() async throws -> AuthServiceProviding {
        try await resolve(AuthServiceProviding.self)
    }

    func getSensorManager() async throws -> SensorManaging {
        try await resolve(SensorManaging.self)
    }
    
    func getBiomarkerService() async throws -> BiomarkerServiceProviding {
        try await resolve(BiomarkerServiceProviding.self)
    }

    func getScoreService() async throws -> ScoreServiceProviding {
        try await resolve(ScoreServiceProviding.self)
    }

    func getDemographicService() async throws -> DemographicServiceProviding {
        try await resolve(DemographicServiceProviding.self)
    }
    
    func getHealthKitService() async throws -> HealthKitProviding {
        try await resolve(HealthKitProviding.self)
    }
}
