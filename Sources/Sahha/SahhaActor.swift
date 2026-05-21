import UIKit

// TODO: Rename Feature/FeatureProtocol -> Feature/FeatureImpl (same as android).

actor SahhaActor {
    static let shared = SahhaActor()

    private var settings: SahhaSettings?
    private var container: DIContainer?
    private var configurationTask: Task<Void, Error>?

    private init() {}

    private let lifecycleObserver = LifecycleObserver()

    // MARK: - Configuration

    func configure(with settings: SahhaSettings) async throws {
        if let configurationTask {
            Sahha.log("[SahhaActor] configure() called but already in progress, awaiting existing task")
            return try await configurationTask.value
        }
        Sahha.log("[SahhaActor] configure() starting fresh (container exists: \(container != nil))")

        self.settings = settings

        configurationTask = Task { [settings] in
            let container = DIContainer()

            await StorageDI.registerDependencies(container: container)
            await DeviceInfoDI.registerDependencies(container: container, settings: settings)
            await NetworkingDI.registerDependencies(container: container, settings: settings)
            await LoggingDI.registerDependencies(container: container)
            await SensorDI.registerDependencies(container: container)
            await AuthDI.registerDependencies(container: container)
            await DataLogDI.registerDependencies(container: container)
            await TagDI.registerDependencies(container: container)
            await HealthKitDI.registerDependencies(container: container)
            await BackgroundDI.registerDependencies(container: container, settings: settings)
            await ScoreDI.registerDependencies(container: container)
            await BiomarkerDI.registerDependencies(container: container)
            await DemographicDI.registerDependencies(container: container)
            await DeviceInfoSyncDI.registerDependencies(container: container)
            await DeviceLogDI.registerDependencies(container: container)
            await DiagnosticsDI.registerDependencies(container: container)

            // Validate and clean up legacy DLQ files from before the unified pipeline
            let userDefaultsStorage = try await container.resolve(UserDefaultsStorageProtocol.self)
            await DLQMigrator.migrateIfNeeded(storage: userDefaultsStorage)

            // Device log listener
            let deviceLogListener = try await container.resolve(DeviceLogLifecycleListener.self)
            await self.lifecycleObserver.registerListener(deviceLogListener)

            // Register interceptors
            let interceptorStore = try await container.resolve(APIInterceptorStoreProtocol.self)
            let authInterceptor = try await container.resolve(AuthorizationInterceptor.self)
            await interceptorStore.addInterceptor(authInterceptor)

            // Start authenticated services if already logged in
            let authManager = try await container.resolve(AuthManagerProtocol.self)
            if  await authManager.hasValidProfileToken() {
                await self.startAuthenticatedServices(container)
            }

            self.container = container
        }
        
        defer { configurationTask = nil }

        return try await configurationTask!.value
    }

    // MARK: - Authenticated Services
    
    func startAuthenticatedServices() async throws {
        let (container, _) = try await requireConfig()
        await startAuthenticatedServices(container)
    }

    private func startAuthenticatedServices(_ container: DIContainer) async {
        async let a: Void = startDataCollection(container)
        async let b: Void = forceSyncDeviceInfo(container)
        async let c: Void = setupLifecycleListeners(container)
        async let d: Void = syncDemographic(container)
        async let e: Void = startBackgroundCoordinator(container)
        _ = await (a, b, c, d, e)
    }

    private func startBackgroundCoordinator(_ container: DIContainer) async {
        do {
            let coordinator = try await container.resolve(BackgroundCoordinatorProtocol.self)
            await coordinator.start()
        } catch {
            await log(error: error, message: "startBackgroundCoordinator failed")
        }
    }

    private func setupLifecycleListeners(_ container: DIContainer) async {
        do {
            let deviceInfoSyncListener = try await container.resolve(DeviceInfoSyncLifecycleListener.self)
            let postInsightsListener = try await container.resolve(PostInsightsLifecycleListener.self)
            let deviceLogListener = try await container.resolve(DeviceLogLifecycleListener.self)
            let dataLogRetryListener = try await container.resolve(DataLogRetryLifecycleListener.self)
            let tagRetryListener = try await container.resolve(TagRetryLifecycleListener.self)
            let sensorHealthCheckListener = try await container.resolve(SensorHealthCheckLifecycleListener.self)
            let sensorProbeListener = try await container.resolve(SensorProbeLifecycleListener.self)
            let diagnosticConfigListener = try await container.resolve(DiagnosticConfigLifecycleListener.self)

            await lifecycleObserver.registerListener(deviceInfoSyncListener, for: [.app_resume])
            await lifecycleObserver.registerListener(postInsightsListener, for: [.app_resume])
            await deviceLogListener.setAuthenticated(true)

            // Retry pending uploads on resume, foreground, and unlock events.
            // This ensures data queued during background delivery (but not uploaded
            // before suspension) gets sent when the app next wakes.
            await lifecycleObserver.registerListener(dataLogRetryListener, for: [.app_resume, .app_foreground, .app_unlocked])
            await lifecycleObserver.registerListener(tagRetryListener, for: [.app_resume, .app_foreground, .app_unlocked])

            // Verify observer health on every foreground event — re-registers any
            // observers silently dropped by iOS (memory pressure, OS updates, etc.)
            await lifecycleObserver.registerListener(sensorHealthCheckListener, for: [.app_foreground])

            // Probe each sensor for data to detect potentially denied permissions
            await lifecycleObserver.registerListener(sensorProbeListener, for: [.app_foreground])

            // Upload diagnostic report on app open. Uses .app_resume (didBecomeActive) rather
            // than .app_foreground because the latter does not fire on cold launch.
            await lifecycleObserver.registerListener(diagnosticConfigListener, for: [.app_resume])
        } catch {
            await log(error: error, message: "setupLifecycleListeners failed")
        }
    }

    private func forceSyncDeviceInfo(_ container: DIContainer) async {
        do {
            let deviceInfoSyncManager = try await container.resolve(DeviceInfoSyncManagerProtocol.self)
            await deviceInfoSyncManager.forceSyncDeviceInfo()
        } catch {
            await log(error: error, message: "forceSyncDeviceInfo failed")
        }
    }

    private func syncDemographic(_ container: DIContainer) async {
        do {
            let demographicManager = try await container.resolve(DemographicManagerProtocol.self)
            var demographic = try await demographicManager.getDemographic()
            if demographic.isComplete { return }
            
            let healthKitManager = try await container.resolve(HealthKitManagerProtocol.self)
            let hkDemographic = try await healthKitManager.getDemographic()
        
            guard !hkDemographic.isEmpty, demographic != hkDemographic else { return }
            
            demographic.mergeWith(hkDemographic)
            try await demographicManager.updateDemographic(demographic)
        } catch {
            await log(error: error, message: "syncDemographic failed")
        }
    }

    private func startDataCollection(_ container: DIContainer) async {
        do {
            let healthKitManager = try await container.resolve(HealthKitManagerProtocol.self)
            await healthKitManager.resumeSensors()
        } catch {
            await log(error: error, message: "startSensors failed")
        }
    }

    // MARK: - Deauthentication

    func deauthenticate() async throws {
        if let task = configurationTask { _ = try await task.value }
        let (container, settings) = try await requireConfig()
        await container.reset()
        DLQMigrator.reset()
        try await configure(with: settings)
    }

    // MARK: - Resolvers

    private func resolve<T: Sendable>(_ type: T.Type = T.self) async throws -> T {
        if let task = configurationTask { _ = try await task.value }
        let (container, _) = try await requireConfig()
        return try await container.resolve(type)
    }

    func authManager() async throws -> AuthManagerProtocol {
        try await resolve(AuthManagerProtocol.self)
    }

    func healthKitManager() async throws -> HealthKitManagerProtocol {
        try await resolve(HealthKitManagerProtocol.self)
    }

    func scoreManager() async throws -> ScoreManagerProtocol {
        try await resolve(ScoreManagerProtocol.self)
    }

    func biomarkerManager() async throws -> BiomarkerManagerProtocol {
        try await resolve(BiomarkerManagerProtocol.self)
    }

    func demographicManager() async throws -> DemographicManagerProtocol {
        try await resolve(DemographicManagerProtocol.self)
    }

    func diagnosticReportBuilder() async throws -> DiagnosticReportBuilderProtocol {
        try await resolve(DiagnosticReportBuilderProtocol.self)
    }

    func diagnosticUploadService() async throws -> DiagnosticUploadServiceProtocol {
        try await resolve(DiagnosticUploadServiceProtocol.self)
    }

    func tagPipeline() async throws -> TagPipelineProtocol {
        try await resolve(TagPipelineProtocol.self)
    }
    
    func backgroundDelegate() async throws -> BackgroundSessionDelegate {
        try await resolve(BackgroundSessionDelegate.self)
    }

    // MARK: - Utilities

    private func log(error: Error, message: String) async {
        if let logger = (try? await container?.resolve(ErrorLoggerProtocol.self)) {
            logger.postError(error)
        } else {
            Sahha.log("\(message): \(error)")
        }
    }
    
    /// Log an error through the DI-resolved ErrorLogger (for public API error logging)
    func logError(_ error: Error) async {
        if let logger = (try? await container?.resolve(ErrorLoggerProtocol.self)) {
            logger.postError(error)
        } else {
            Sahha.log("[Sahha] Error (logger unavailable): \(error)")
        }
    }

    func requireConfig() async throws -> (DIContainer, SahhaSettings) {
        guard let container, let settings else {
            throw SahhaError(message: "Sahha is not configured. Please call `Sahha.configure(...)` first.")
        }
        return (container, settings)
    }

    // MARK: - Post Error

    func postError(framework: SahhaFramework = .ios_swift, message: String, path: String, method: String, body: String) async {
        // Use DI-resolved API client if available (includes auth interceptor)
        let apiClient: APIClientProtocol
        if let resolvedClient = try? await container?.resolve(APIClientProtocol.self) {
            apiClient = resolvedClient
        } else {
            // Fallback to basic client without auth (for pre-configuration errors)
            let baseURL = settings?.environment.baseURL ?? SahhaEnvironment.sandbox.baseURL
            apiClient = APIClient(baseURL: baseURL)
        }
        
        let deviceIdProvider = DeviceIdProvider(storage: UserDefaultsStorage())
        let deviceInfo = await DeviceInfoBuilder(sdkId: framework.rawValue, deviceIdProvider: deviceIdProvider).build()
        let errorLog = ErrorLogRequest(
            sdkId: deviceInfo.sdkId,
            sdkVersion: deviceInfo.sdkVersion,
            appId: deviceInfo.appId,
            appVersion: deviceInfo.appVersion,
            deviceId: deviceInfo.deviceId,
            deviceType: deviceInfo.deviceType,
            deviceModel: deviceInfo.deviceModel,
            system: deviceInfo.system,
            systemVersion: deviceInfo.systemVersion,
            errorSource: ErrorSource.sdk.rawValue,
            errorLocation: framework.rawValue,
            errorMessage: message,
            codePath: path,
            codeMethod: method,
            codeBody: body
        )
        let request = APIRequest(
            endpoint: APIEndpoints.error,
            method: .POST,
            body: errorLog,
            requiresAuth: true
        )
        do {
            try await apiClient.send(request)
            Sahha.log("[Sahha] Error log sent successfully")
        } catch {
            Sahha.log("[Sahha] Failed to send error log: \(error.localizedDescription)")
        }
    }
}
