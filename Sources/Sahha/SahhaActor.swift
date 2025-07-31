import UIKit

actor SahhaActor {
    static let shared = SahhaActor()

    private var settings: SahhaSettings?
    private var container: DIContainer?
    private var configurationTask: Task<Void, Never>?

    private init() {}
    
    // MARK: - Configuration
    func configure(with settings: SahhaSettings) async {
        if let configurationTask {
            return await configurationTask.value
        }

        self.settings = settings

        configurationTask = Task {
            defer { configurationTask = nil }

            let container = DIContainer()

            await StorageDI.registerDependencies(container: container)
            await DeviceInfoDI.registerDependencies(container: container, settings: settings)
            await NetworkingDI.registerDependencies(container: container, settings: settings)
            await LoggingDI.registerDependencies(container: container)
            await SensorDI.registerDependencies(container: container)
            await AuthDI.registerDependencies(container: container)
            await DataLogDI.registerDependencies(container: container)
            await HealthKitDI.registerDependencies(container: container)
            await ScoreDI.registerDependencies(container: container)
            await BiomarkerDI.registerDependencies(container: container)
            await DemographicDI.registerDependencies(container: container)
            await DeviceInfoSyncDI.registerDependencies(container: container)
            await LifecycleDI.registerDependencies(container: container)
            await DeviceLogDI.registerDependencies(container: container)

            await registerInterceptors(container: container)
            self.container = container
            await startAuthenticatedServices()
        }
        await configurationTask?.value
    }

    // MARK: Deauthentication
    func deauthenticate() async throws {
        if let task = configurationTask { await task.value }
        guard let container, let settings else {
            throw SahhaError(message: "Sahha is not configured. Please call `Sahha.configure(...)` first.")
        }
        await container.reset()
        await configure(with: settings)
    }

    // MARK: - Error Logging
    private func handleError(_ error: Error) async {
        if let logger = try? await container?.resolve(ErrorLoggerProtocol.self) {
            logger.postError(error)
        }
    }

    /// Legacy support for sending errors via Sahha.postError(...)
    func postError(framework: SahhaFramework = .ios_swift, message: String, path: String, method: String, body: String) async {
        let baseURL = settings?.environment.baseURL ?? SahhaEnvironment.sandbox.baseURL
        let apiClient = APIClient(baseURL: baseURL)
        let deviceIdProvider = DeviceIdProvider(storage: UserDefaultsStorage())
        let deviceInfo = await DeviceInfoBuilder(sdkId: framework.rawValue,deviceIdProvider: deviceIdProvider).build()
        let error = ErrorLogRequest(
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
            body: error
        )
        try? await apiClient.send(request)
    }

    // MARK: - Interceptors
    private func registerInterceptors(container: DIContainer) async {
        do {
            let interceptorStore = try await container.resolve(APIInterceptorStoreProtocol.self)
            let authInterceptor = try await container.resolve(AuthorizationInterceptor.self)

            await interceptorStore.addInterceptor(authInterceptor)
        } catch {
            await handleError(error)
        }
    }

    // MARK: - Authenticated Services
    func startAuthenticatedServices() async {
        guard let container else { return }
        do {
            let authManager = try await container.resolve(AuthManagerProtocol.self)
            let isAuthenticated = await authManager.hasValidProfileToken()

            if isAuthenticated {
                forceSyncDeviceInfo(container: container)
                syncDemographic(container: container)
                startSensors(container: container)
                setupLifecycleListeners(container: container)
            }
        } catch {
            await handleError(error)
        }
    }

    // MARK: - Force Sync Device Info
    private func forceSyncDeviceInfo(container: DIContainer) {
        Task {
            do {
                let deviceInfoSyncManager = try await container.resolve(DeviceInfoSyncManagerProtocol.self)
                await deviceInfoSyncManager.forceSyncDeviceInfo()
            } catch {
                await handleError(error)
            }
        }
    }

    // MARK: - Sync Demographic
    private func syncDemographic(container: DIContainer) {
        Task {
            do {
                let demographicManager = try await container.resolve(DemographicManagerProtocol.self)
                var demographic = try await demographicManager.getDemographic()
                // If demographic is complete return early
                if demographic.isComplete { return }
                let healthKitManager = try await container.resolve(HealthKitManagerProtocol.self)
                let hkDemographic = try await healthKitManager.getDemographic()
                // if no hkDemographic or demographics are the same return early
                guard !hkDemographic.isEmpty, demographic != hkDemographic else { return }
                demographic.mergeWith(hkDemographic)
                try await demographicManager.updateDemographic(demographic)
            } catch {
                await handleError(error)
            }
        }
    }

    // MARK: - Lifecycle Listeners
    private func setupLifecycleListeners(container: DIContainer) {
        Task {
            do {
                let lifecycleObserver = try await container.resolve(LifecycleObserverProtocol.self)
                let deviceInfoSyncListener = try await container.resolve(DeviceInfoSyncLifecycleListener.self)
                let postInsightsListener = try await container.resolve(PostInsightsLifecycleListener.self)
                let deviceLogListener = try await container.resolve(DeviceLogLifecycleListener.self)

                await lifecycleObserver.registerListener(deviceInfoSyncListener, for: [.app_resume])
                await lifecycleObserver.registerListener(postInsightsListener, for: [.app_resume])
                await lifecycleObserver.registerListener(deviceLogListener)
            } catch {
                await handleError(error)
            }
        }
    }

    // MARK: - Start Sensors
    private func startSensors(container: DIContainer) {
        Task {
            do {
                let dataLogUploader = try await container.resolve(DataLogUploaderProtocol.self)
                let healthKitManager = try await container.resolve(HealthKitManagerProtocol.self)
                
                await dataLogUploader.uploadPendingBatches()
                await healthKitManager.resumeSensors()
            } catch {
                await handleError(error)
            }
        }
    }

    // MARK: - Resolvers
    private func resolve<T: Sendable>(_ type: T.Type = T.self) async throws -> T {
        if let task = configurationTask { await task.value }
        guard let container else {
            throw SahhaError(message: "Sahha is not configured. Please call `Sahha.configure(...)` first.")
        }
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
}
