final actor SahhaContainer {
    static let shared = SahhaContainer()

    private var container: DIContainer?
    private var configurationTask: Task<Void, Error>?

    private init() {}

    func configure(with settings: SahhaSettings) async throws {
        // Already configured, return early.
        guard container == nil else { return }
        
        container = DIContainer(sahhaSettings: settings)
        
        await container?.registerSingleton(DeviceInformation.self) { container in
            await DeviceInformationProvider().getDeviceInformation(settings: settings)
        }

        configurationTask = Task {
            // Register all providers sequentially
            try await container?.registerProvider(APIProvider())
            try await container?.registerProvider(LoggingProvider())
            try await container?.registerProvider(DataLogProvider())
            try await container?.registerProvider(LifecycleProvider())
            try await container?.registerProvider(AuthenticationProvider())
            try await container?.registerProvider(DemographicProvider())
            try await container?.registerProvider(HealthKitProvider())
            try await container?.registerProvider(SensorsProvider())
            try await container?.registerProvider(DeviceProvider())
            try await container?.registerProvider(BiomarkerProvider())
            try await container?.registerProvider(ScoreProvider())
        }

        // Wait for the configuration to complete
        try await configurationTask?.value
        configurationTask = nil
    }

    func startAuthenticatedServices() async throws {
        let deviceManager = try await getDeviceManager()
        await deviceManager.syncDeviceInformation()
        await deviceManager.trackLifecycleEvents()
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

    private func resolve<T: Sendable>(_ type: T.Type) async throws -> T {
        // If configuration is in progress, wait for it to complete
        if let task = configurationTask {
            try await task.value
        }
        guard let container else {
            throw SahhaError.notConfigured
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

    func getDeviceManager() async throws -> DeviceManagerProtocol {
        return try await resolve(DeviceManagerProtocol.self)
    }

    func getDemographicManager() async throws -> DemographicManagerProtocol {
        return try await resolve(DemographicManagerProtocol.self)
    }

    func getSensorsManager() async throws -> SensorsManagerProtocol {
        return try await resolve(SensorsManagerProtocol.self)
    }
    
    func getHealthKitManager() async throws -> HealthKitManagerProtocol {
        return try await resolve(HealthKitManagerProtocol.self)
    }
}
