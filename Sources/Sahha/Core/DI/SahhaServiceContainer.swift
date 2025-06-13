import Foundation

enum SahhaError: Error, LocalizedError {
    case notConfigured
    
    var errorDescription: String {
        switch self {
        case .notConfigured:
            return "Sahha not configured. Call Sahha.configure(...) first."
        }
    }
}

actor SahhaServiceContainer {
    static let shared = SahhaServiceContainer()
    
    private let container = DIContainer.shared
    private var isConfigured = false
    private var cachedSettings: SahhaSettings?
    
    private init() {}
    
    func configure(with settings: SahhaSettings) async {
        guard !isConfigured else {
            print("Sahha already configured.")
            return
        }
        
        // Cache settings for potential reset/rebuild
        cachedSettings = settings
        
        // Register APIService
        await container.registerSingleton(APIServiceProtocol.self) {
            return APIService(baseURL: settings.environment.baseURL)
        }
        
        // Register AuthenticationService
        await container.registerSingleton(AuthenticationServiceProtocol.self) { container in
            let apiService = try await container.resolveAsync(APIServiceProtocol.self)
            return AuthenticationService(apiService: apiService)
        }
        
        // Register TokenManager
        await container.registerSingleton(TokenManagerProtocol.self) { container in
            let tokenStorage = KeychainStorage<AuthenticationResponse>(account: "SahhaToken")
            let apiService = try await container.resolveAsync(APIServiceProtocol.self)
            return TokenManager(storage: tokenStorage, apiService: apiService)
        }
        
        // Register SecureAPIService
        await container.registerSingleton(SecureAPIServiceProtocol.self) { container in
            let tokenManager = try await container.resolveAsync(TokenManagerProtocol.self)
            let apiService = try await container.resolveAsync(APIServiceProtocol.self)
            return SecureAPIService(apiService: apiService, tokenManager: tokenManager)
        }
        
        // Register DeviceInfoManager
        await container.registerSingleton(DeviceInfoManagerProtocol.self) {
            return DeviceInfoManager(userDefaults: .standard, settings: settings)
        }
        
        // Register DeviceInfoService
        await container.registerSingleton(DeviceInfoServiceProtocol.self) { container in
            let apiService = try await container.resolveAsync(SecureAPIServiceProtocol.self)
            let deviceInfoManager = try await container.resolveAsync(DeviceInfoManagerProtocol.self)
            return DeviceInfoService(apiService: apiService, deviceInfoManager: deviceInfoManager)
        }
        
        // Register LifecycleObserver
        await container.registerSingleton(LifecycleObserverProtocol.self) { container in
            let deviceInfoService = try await container.resolveAsync(DeviceInfoServiceProtocol.self)
            return LifecycleObserver(deviceInfoService: deviceInfoService)
        }
        
        // Register BiomarkerService
        await container.registerSingleton(BiomarkerServiceProtocol.self) { container in
            let apiService = try await container.resolveAsync(SecureAPIServiceProtocol.self)
            return BiomarkerService(apiService: apiService)
        }
        
        // Register ScoreService
        await container.registerSingleton(ScoreServiceProtocol.self) { container in
            let apiService = try await container.resolveAsync(SecureAPIServiceProtocol.self)
            return ScoreService(apiService: apiService)
        }
        
        print("Is LifecycleObserverProtocol registered? \(await container.isRegistered(LifecycleObserverProtocol.self))")
        print("Is DeviceInfoServiceProtocol registered? \(await container.isRegistered(DeviceInfoServiceProtocol.self))")
        print("Is SecureAPIServiceProtocol registered? \(await container.isRegistered(SecureAPIServiceProtocol.self))")
        print("Is DeviceInfoManagerProtocol registered? \(await container.isRegistered(DeviceInfoManagerProtocol.self))")
        
        // Start lifecycle observer
        do {
            let lifecycleObserver = try await container.resolve(LifecycleObserverProtocol.self)
            await lifecycleObserver.startObserving()
        } catch {
            print("Failed to resolve LifecycleObserver: \(error)")
        }
        
        isConfigured = true
        print("Sahha services configured for environment: \(settings.environment.rawValue)")
    }
    
    // MARK: Services
    
    private func resolveService<T: Sendable>(_ type: T.Type) async throws -> T {
        guard isConfigured else {
            throw SahhaError.notConfigured
        }
        return try await container.resolve(type)
    }
    
    func getAuthenticationService() async throws -> AuthenticationServiceProtocol {
        try await resolveService(AuthenticationServiceProtocol.self)
    }
    
    func getDeviceInfoService() async throws -> DeviceInfoServiceProtocol {
        try await resolveService(DeviceInfoServiceProtocol.self)
    }
    
    func getBiomarkerService() async throws -> BiomarkerServiceProtocol {
        try await resolveService(BiomarkerServiceProtocol.self)
    }
    
    func getScoreService() async throws -> ScoreServiceProtocol {
        try await resolveService(ScoreServiceProtocol.self)
    }
    
    // MARK: Managers
    
    func getTokenManager() async throws -> TokenManagerProtocol {
        try await resolveService(TokenManagerProtocol.self)
    }
    
    func getCurrentSettings() -> SahhaSettings? {
        return cachedSettings
    }
    
    func isServiceConfigured() -> Bool {
        return isConfigured
    }
    
    func reset() async {
        await container.reset()
        isConfigured = false
        cachedSettings = nil
        print("Sahha services reset")
    }
    
    func rebuild() async {
        guard let settings = cachedSettings else {
            print("No cached settings available for rebuild")
            return
        }
        
        await reset()
        await configure(with: settings)
        print("Sahha services rebuilt from cached settings")
    }
}
