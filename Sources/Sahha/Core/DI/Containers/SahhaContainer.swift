final actor SahhaContainer {
    static let shared = SahhaContainer()

    private var container: DIContainer?
    private var configurationTask: Task<Void, Error>?

    private init() {}

    func configure(with settings: SahhaSettings) async throws {
        // Already configured, return early.
        guard container == nil else { return }
        
        container = DIContainer(sahhaSettings: settings)

        configurationTask = Task {
            // Register all providers sequentially
            try await container?.registerProvider(APIProvider())
            try await container?.registerProvider(LoggingProvider())
            try await container?.registerProvider(LifecycleProvider())
            try await container?.registerProvider(DeviceInformationProvider())
            try await container?.registerProvider(AuthenticationProvider())
            try await container?.registerProvider(DemographicProvider())
            try await container?.registerProvider(DataLogProvider())
            try await container?.registerProvider(HealthKitProvider())
            try await container?.registerProvider(SensorsProvider())
            try await container?.registerProvider(AppEventProvider())
            try await container?.registerProvider(BiomarkerProvider())
            try await container?.registerProvider(ScoreProvider())
        }

        // Wait for the configuration to complete
        try await configurationTask?.value
        configurationTask = nil
    }

    func startAuthenticatedServices() async throws {
        let deviceInfoManager = try await getDeviceInformationManager()
        await deviceInfoManager.start()
        let appEventManager = try await getAppEventManager()
        await appEventManager.start()
        let sensorsManager = try await getSensorsManager()
        try await sensorsManager.resumeSensors()
    }

    func resetContainer() async throws {
        guard let settings = container?.sahhaSettings else {
            throw SahhaError.missingConfiguration
        }
        if let oldContainer = container {
            try await oldContainer.reset()
        }
        container = nil
        try await configure(with: settings)
    }

    private func requiresAuthentication<T: Sendable>(_ type: T.Type) -> Bool {
        let protectedTypes: [any Sendable.Type] = [
            DeviceInformationServiceProtocol.self,
            DeviceInformationManagerProtocol.self,
            DemographicManagerProtocol.self,
            SensorsManagerProtocol.self,
            AppEventManagerProtocol.self,
        ]
        return protectedTypes.contains { $0 == type }
    }

    private func resolve<T: Sendable>(_ type: T.Type) async throws -> T {
        // If configuration is in progress, wait for it to complete
        if let task = configurationTask {
            try await task.value
        }
        guard let container else {
            throw SahhaError.notConfigured
        }
        if requiresAuthentication(type) {
            guard await Sahha.isAuthenticated else {
                throw SahhaError.unauthorized
            }
        }
        return try await container.resolve(type)
    }

    // MARK: Services

    func getAPIService() async throws -> APIServiceProtocol {
        return try await resolve(APIServiceProtocol.self)
    }

    func getAuthenticationService() async throws -> AuthenticationServiceProtocol {
        return try await resolve(AuthenticationServiceProtocol.self)
    }

    func getDeviceInformationService() async throws -> DeviceInformationServiceProtocol {
        return try await resolve(DeviceInformationServiceProtocol.self)
    }

    func getDemographicService() async throws -> DemographicServiceProtocol {
        return try await resolve(DemographicServiceProtocol.self)
    }

    func getBiomarkerService() async throws -> BiomarkerServiceProtocol {
        return try await resolve(BiomarkerServiceProtocol.self)
    }

    func getScoreService() async throws -> ScoreServiceProtocol {
        return try await resolve(ScoreServiceProtocol.self)
    }

    // MARK: Managers

    func getLogger() async throws -> LoggerProtocol {
        return try await resolve(LoggerProtocol.self)
    }

    func getTokenManager() async throws -> TokenManagerProtocol {
        return try await resolve(TokenManagerProtocol.self)
    }

    func getDeviceInformationManager() async throws -> DeviceInformationManagerProtocol {
        return try await resolve(DeviceInformationManagerProtocol.self)
    }

    func getDemographicManager() async throws -> DemographicManagerProtocol {
        return try await resolve(DemographicManagerProtocol.self)
    }

    func getSensorsManager() async throws -> SensorsManagerProtocol {
        return try await resolve(SensorsManagerProtocol.self)
    }

    func getAppEventManager() async throws -> AppEventManagerProtocol {
        return try await resolve(AppEventManagerProtocol.self)
    }
}
