import UIKit

// TODO: Rename Feature/FeatureProtocol -> Feature/FeatureImpl (same as android).

actor SahhaActor {
    static let shared = SahhaActor()

    /// Registers a dependency graph into a fresh container on every (re)configure.
    typealias DependencyRegistrar = @Sendable (DIContainer, SahhaSettings) async -> Void

    private var settings: SahhaSettings?
    private var container: DIContainer?
    private var configurationTask: Task<Void, Error>?

    private let registrar: DependencyRegistrar
    private let lifecycleObserver: any LifecycleObserverProtocol
    private let retryMonitorFactory: @Sendable () -> NetworkMonitor

    // MARK: Deferred bring-up state (PRD #76 D10)

    /// Scheduling machine for the deferred bring-up. Replaced wholesale on every
    /// configure ("every configure resets the machine").
    private var retryPolicy = BringUpRetryPolicy()
    /// The verdict that caused the current deferral — the unlock trigger treats a
    /// locked-keychain deferral differently from a network one.
    private var deferredVerdict: LaunchAuthVerdict?
    /// Held strongly: the lifecycle observer holds listeners weakly.
    private var bringUpRetryListener: BringUpRetryLifecycleListener?
    /// Dedicated connectivity monitor, alive only while a deferral is
    /// outstanding. Deliberately outside the DI container — `container.reset()`
    /// can never see it, so it is stopped explicitly on completion, stand-down,
    /// reconfigure, and deauthentication.
    private var retryMonitor: NetworkMonitor?
    /// Single-flight + completed latch for the private bring-up method, shared by
    /// the launch gate, the public authenticate path, and every retry trigger.
    private var bringUpTask: Task<Void, Never>?
    private var bringUpCompleted = false
    /// Bumped by every configure reset so a bring-up pass that straddles a
    /// reconfigure cannot latch the fresh machine.
    private var bringUpGeneration: UInt64 = 0

    /// Non-shared instances exist for integration tests: inject a registrar that
    /// swaps storage/network registrations for doubles, an observer spy so no
    /// NotificationCenter observers are installed, and a monitor factory that
    /// returns a test-controlled `NetworkMonitor`.
    init(
        registrar: @escaping DependencyRegistrar = SahhaActor.registerProductionDependencies,
        lifecycleObserver: any LifecycleObserverProtocol = LifecycleObserver(),
        retryMonitorFactory: @escaping @Sendable () -> NetworkMonitor = { NetworkMonitor() }
    ) {
        self.registrar = registrar
        self.lifecycleObserver = lifecycleObserver
        self.retryMonitorFactory = retryMonitorFactory
    }

    static func registerProductionDependencies(container: DIContainer, settings: SahhaSettings) async {
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
    }

    // MARK: - Configuration

    func configure(with settings: SahhaSettings) async throws {
        if let configurationTask {
            Sahha.log("[SahhaActor] configure() called but already in progress, awaiting existing task")
            return try await configurationTask.value
        }
        Sahha.log("[SahhaActor] configure() starting fresh (container exists: \(container != nil))")

        self.settings = settings

        configurationTask = Task { [settings] in
            // Every configure resets the deferred bring-up machine (PRD #76 D10):
            // the fresh container must not inherit backoff windows, attempt
            // budgets, a completed latch, or a live monitor from its predecessor.
            await self.resetDeferredBringUp()
            // The retry listener registers before the auth gate so a deferred
            // verdict has its triggers in place with no gap; registration is
            // identity-deduped, so repeat configures do not stack listeners.
            await self.registerBringUpRetryListener()

            let container = DIContainer()

            await self.registrar(container, settings)

            // Validate and clean up legacy DLQ files from before the unified pipeline
            let userDefaultsStorage = try await container.resolve(UserDefaultsStorageProtocol.self)
            await DLQMigrator.migrateIfNeeded(storage: userDefaultsStorage)

            // Device log listener
            let deviceLogListener = try await container.resolve(DeviceLogLifecycleListener.self)
            await self.lifecycleObserver.registerListener(deviceLogListener)

            // Register interceptors
            // NOTE: keep AuthorizationInterceptor registered FIRST. APIClient.buildNext folds
            // the chain so earlier registrations are inner links, and the auth interceptor's
            // 401 retry re-invokes only its own `next` — an interceptor registered before it
            // would be re-executed on every retried request.
            let interceptorStore = try await container.resolve(APIInterceptorStoreProtocol.self)
            let authInterceptor = try await container.resolve(AuthorizationInterceptor.self)
            await interceptorStore.addInterceptor(authInterceptor)

            // Start authenticated services if already logged in
            let authManager = try await container.resolve(AuthManagerProtocol.self)

            // The container must be visible before authenticated bring-up: errors logged
            // during bring-up resolve the error logger through `self.container`, and
            // assigning it afterwards sent every configure-time bring-up failure to the
            // no-op debug logger instead. All throwing steps stay above this line, so a
            // failed configure still leaves the actor unconfigured.
            self.container = container

            // Token-refresh piggyback (D10): a successful refresh anywhere in the
            // SDK proves the session valid and the network reachable — exactly
            // what a deferred bring-up is waiting on. Dispatched on a fresh task
            // because the handler runs inside the refresh flight, and re-entering
            // the auth manager synchronously would self-join that flight.
            await authManager.setOnRefreshSuccess { [weak self] in
                Task { await self?.handleTokenRefreshPiggyback() }
            }

            let verdict = await authManager.launchVerdict()
            switch verdict {
            case .valid:
                await self.startAuthenticatedServices(container)
            case .unauthenticated, .terminalSessionExpiry:
                // Nothing a retry could change: signed out, or the session is
                // already cleared. The retry machine stays dormant.
                break
            case .transientRefreshFailure, .tokenStoreUnreadable:
                await self.deferBringUp(after: verdict)
            }
        }
        
        defer { configurationTask = nil }

        return try await configurationTask!.value
    }

    // MARK: - Authenticated Services
    
    func startAuthenticatedServices() async throws {
        let (container, _) = try await requireConfig()
        await startAuthenticatedServices(container)
    }

    /// Single-flight bring-up with a completed latch (PRD #76 D10). The launch
    /// gate, the public authenticate path, and every deferred-retry trigger
    /// funnel through here; without the shared guard, a retry racing an
    /// authenticate would run the bring-up twice — and a second pass arms one
    /// live observer query per sensor through a second door (the leak #86
    /// closes at the store level). Concurrent callers join the running pass;
    /// post-completion callers are no-ops until the next configure resets the
    /// latch.
    private func startAuthenticatedServices(_ container: DIContainer) async {
        if bringUpCompleted { return }
        if let bringUpTask {
            return await bringUpTask.value
        }
        let generation = bringUpGeneration
        let task = Task { await self.runAuthenticatedBringUp(container) }
        bringUpTask = task
        await task.value
        // Only the starter clears the flight, and only when no configure reset
        // the machine while the pass ran — a pass that straddles a reconfigure
        // must not latch the fresh machine's gate.
        if generation == bringUpGeneration {
            bringUpTask = nil
            bringUpCompleted = true
        }
    }

    private func runAuthenticatedBringUp(_ container: DIContainer) async {
        async let a: Void = startDataCollection(container)
        async let b: Void = forceSyncDeviceInfo(container)
        async let c: Void = setupLifecycleListeners(container)
        async let d: Void = syncDemographic(container)
        async let e: Void = startBackgroundCoordinator(container)
        _ = await (a, b, c, d, e)
        // Deterministic bring-up tail (PRD #76 D8 + D11), after every branch
        // above — observer arming included — so it runs identically on the
        // launch, authenticate, and deferred-retry paths. Lifecycle listeners
        // cannot stand in for this: the resume event can fire before listeners
        // register on cold launch and be lost. The health check runs before the
        // probe+report so the report describes the repaired state.
        await postPendingSensorStoreAnomaly(container)
        await runSensorHealthCheck(container)
        await uploadDiagnosticReport(container)
    }

    // MARK: - Deferred bring-up retry (PRD #76 D10)

    private func resetDeferredBringUp() async {
        bringUpGeneration &+= 1
        bringUpTask = nil
        bringUpCompleted = false
        retryPolicy = BringUpRetryPolicy()
        deferredVerdict = nil
        await stopRetryMonitor()
    }

    private func registerBringUpRetryListener() async {
        if bringUpRetryListener == nil {
            bringUpRetryListener = BringUpRetryLifecycleListener { [weak self] event in
                await self?.handleBringUpRetryTrigger(event)
            }
        }
        guard let bringUpRetryListener else { return }
        // Resume and foreground cover ordinary app use; unlock is the designated
        // signal for the locked-keychain deferral (protected data became
        // available). One listener, one mechanism.
        await lifecycleObserver.registerListener(
            bringUpRetryListener,
            for: [.app_resume, .app_foreground, .app_unlocked]
        )
    }

    private func deferBringUp(after verdict: LaunchAuthVerdict) async {
        deferredVerdict = verdict
        retryPolicy.arm(at: Date())
        await startRetryMonitor()
        Sahha.log("[SahhaActor] Authenticated bring-up deferred (\(verdict)); retrying on lifecycle, unlock, and network events")
    }

    private func handleBringUpRetryTrigger(_ event: LifecycleEvent?) async {
        guard container != nil else { return }
        // The unlock event is the designated retry signal for a locked-keychain
        // deferral: the blocking cause is gone by definition, so it does not
        // wait out a backoff window sized for network failures. (The hard
        // inter-attempt floor still applies.)
        if event == .app_unlocked, deferredVerdict == .tokenStoreUnreadable {
            retryPolicy.noteStateChange(resettingAttempts: false)
        }
        guard retryPolicy.admitTrigger(at: Date()) else { return }
        await runDeferredBringUpAttempt()
    }

    private func handleNetworkRestored() async {
        // An offline→online transition is direct evidence the transient cause is
        // gone: bypass the current backoff window once and grant a fresh attempt
        // budget (D10).
        retryPolicy.noteStateChange(resettingAttempts: true)
        await handleBringUpRetryTrigger(nil)
    }

    private func handleTokenRefreshPiggyback() async {
        guard retryPolicy.isArmed else { return }
        // A successful refresh already proved the session valid and the network
        // up, so the attempt is admitted directly: the verdict re-read is
        // answered from the just-saved token without a network call, and the
        // bring-up's own single-flight latch collapses duplicates. The backoff
        // gate exists to space out doomed network retries — this path cannot
        // generate one.
        await runDeferredBringUpAttempt()
    }

    private func runDeferredBringUpAttempt() async {
        guard let container else { return }
        // The only exit from a locked-keychain deferral is a successful reload;
        // for every other verdict the reload is a no-op.
        if let tokenStore = try? await container.resolve(TokenStoreProtocol.self) {
            await tokenStore.reloadPersistedSession()
        }
        guard let authManager = try? await container.resolve(AuthManagerProtocol.self) else { return }
        let verdict = await authManager.launchVerdict()
        switch verdict {
        case .valid:
            await startAuthenticatedServices(container)
            retryPolicy.recordSuccess()
            await stopRetryMonitor()
        case .unauthenticated, .terminalSessionExpiry:
            // The deferral outlived the session (deauthenticated, or the refresh
            // token died for good): stand down for the life of this configure.
            retryPolicy.standDown()
            deferredVerdict = nil
            await stopRetryMonitor()
        case .transientRefreshFailure, .tokenStoreUnreadable:
            deferredVerdict = verdict
            retryPolicy.recordFailure(at: Date())
        }
    }

    private func startRetryMonitor() async {
        guard retryMonitor == nil else { return }
        let monitor = retryMonitorFactory()
        retryMonitor = monitor
        _ = await monitor.onStateChange { [weak self] connected in
            guard connected else { return }
            await self?.handleNetworkRestored()
        }
        await monitor.startMonitoring()
    }

    private func stopRetryMonitor() async {
        guard let monitor = retryMonitor else { return }
        retryMonitor = nil
        await monitor.dispose()
    }

    /// Posts the anomaly latched by the sensor store's first lenient read (a
    /// healed 1.3.7-era set, a foreign value, undecodable data). Latched rather
    /// than posted at read time so it lands here, authenticated, instead of
    /// firing pre-auth and being lost.
    private func postPendingSensorStoreAnomaly(_ container: DIContainer) async {
        do {
            let sensorStore = try await container.resolve(SensorStoreProtocol.self)
            if let anomaly = await sensorStore.drainPendingAnomaly() {
                await log(error: SahhaError(message: anomaly.description), message: "sensor store anomaly")
            }
        } catch {
            await log(error: error, message: "postPendingSensorStoreAnomaly failed")
        }
    }

    /// One explicit health check after observer arming (PRD #76 D11): repairs
    /// observers or background delivery dropped since the last launch. The
    /// service is single-flighted, so this trigger and the `.app_foreground`
    /// listener can never run two re-arm passes concurrently.
    private func runSensorHealthCheck(_ container: DIContainer) async {
        do {
            let healthCheckService = try await container.resolve(SensorHealthCheckServiceProtocol.self)
            await healthCheckService.runHealthCheck()
        } catch {
            await log(error: error, message: "bring-up sensor health check failed")
        }
    }

    private func uploadDiagnosticReport(_ container: DIContainer) async {
        do {
            let uploadService = try await container.resolve(DiagnosticUploadServiceProtocol.self)
            try await uploadService.uploadDiagnosticReport()
        } catch {
            await log(error: error, message: "bring-up diagnostic upload failed")
        }
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
        // The retry monitor lives outside the container, so reset() cannot stop
        // it; a deferred retry must not survive deauthentication (PRD #76 D10).
        await stopRetryMonitor()
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

    private func log(error: Error, message: String, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) async {
        if let logger = (try? await container?.resolve(ErrorLoggerProtocol.self)) {
            logger.postError(error, file: file, function: function, line: line)
        } else {
            Sahha.log("\(message): \(error)")
        }
    }

    /// Log an error through the DI-resolved ErrorLogger (for public API error logging).
    /// The file/function/line defaults resolve at the caller, so forwarded errors report
    /// the reporting site rather than this method.
    func logError(_ error: Error, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) async {
        if let logger = (try? await container?.resolve(ErrorLoggerProtocol.self)) {
            logger.postError(error, file: file, function: function, line: line)
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
