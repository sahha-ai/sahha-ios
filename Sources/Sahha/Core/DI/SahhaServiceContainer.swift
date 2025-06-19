import Foundation
import HealthKit

enum SahhaError: Error, LocalizedError {
    case notConfigured
    case alreadyConfigured
    case lifecycleObserverResolutionFailed(underlyingError: Error)
    
    var errorDescription: String {
        switch self {
        case .notConfigured:
            return "Sahha not configured. Call Sahha.configure(...) first."
        case .alreadyConfigured:
            return "Sahha is already configured."
        case .lifecycleObserverResolutionFailed(let underlyingError):
            return "Failed to resolve or start LifecycleObserver. Underlying error: \(underlyingError.localizedDescription)"
        }
    }
}

actor SahhaServiceContainer {
    static let shared = SahhaServiceContainer()
    
    private let container = DIContainer()
    private var isConfigured = false
    private var cachedSettings: SahhaSettings?
    
    private init() {}
    
    func configure(with settings: SahhaSettings) async throws {
        guard !isConfigured else {
            throw SahhaError.alreadyConfigured
        }
        
        // Cache settings for potential reset/rebuild
        cachedSettings = settings
        
        // Register APIService
        await container.register(APIServiceProtocol.self) { _ in
            return APIService(baseURL: settings.environment.baseURL)
        }
        
        // Register AuthenticationService
        await container.register(AuthenticationServiceProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            return AuthenticationService(apiService: apiService)
        }
        
        // Register TokenManager
        await container.register(TokenManagerProtocol.self) {container in
            let tokenStorage = KeychainStorage<AuthenticationResponse>(account: "token")
            let apiService = try await container.resolve(APIServiceProtocol.self)
            return TokenManager(storage: tokenStorage, apiService: apiService)
        }
        
        // Register SecureAPIService
        await container.register(SecureAPIServiceProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            let tokenManager = try await container.resolve(TokenManagerProtocol.self)
            return SecureAPIService(apiService: apiService, tokenManager: tokenManager)
        }
        
        // Register DeviceInfoService
        await container.register(DeviceInfoServiceProtocol.self) { container in
            let apiService = try await container.resolve(SecureAPIServiceProtocol.self)
            return DeviceInfoService(apiService: apiService)
        }
        
        // Register DemographicService
        await container.register(DemographicServiceProtocol.self) { container in
            let apiService = try await container.resolve(SecureAPIServiceProtocol.self)
            return DemographicService(apiService: apiService)
        }
        
        // Register BiomarkerService
        await container.register(BiomarkerServiceProtocol.self) { container in
            let apiService = try await container.resolve(SecureAPIServiceProtocol.self)
            return BiomarkerService(apiService: apiService)
        }
        
        // Register ScoreService
        await container.register(ScoreServiceProtocol.self) { container in
            let apiService = try await container.resolve(SecureAPIServiceProtocol.self)
            return ScoreService(apiService: apiService)
        }
        
        // Register DeviceInfoManager
        await container.register(DeviceInfoManagerProtocol.self) { container in
            let deviceInfoService = try await container.resolve(DeviceInfoServiceProtocol.self)
            return DeviceInfoManager(userDefaults: .standard, settings: settings, deviceInfoService: deviceInfoService)
        }
        
        // Register DemographicManager
        await container.register(DemographicManagerProtocol.self) { container in
            let demographicService = try await container.resolve(DemographicServiceProtocol.self)
            return DemographicManager(userDefaults: .standard, demographicSerivce: demographicService)
        }
        
        // Register LifecycleObserver
        await container.register(LifecycleObserverProtocol.self) { container in
            let deviceInfoManager = try await container.resolve(DeviceInfoManagerProtocol.self)
            return LifecycleObserver(deviceInfoManager: deviceInfoManager)
        }
        
        // Register DataLogPipeline
        await container.register((any DataLogProcessorProtocol).self) { container in
            return DataLogProcessor()
        }
        
        // Register HKManager
        await container.register(HKManagerProtocol.self) { container in
            let anchorStorage = HKAnchorStorage()
            let processor = try await container.resolve((any DataLogProcessorProtocol).self)
            
            let normalisers: [HKSampleType: any HKNormaliser] = [
                HKQuantityType(.stepCount): HKStepCountNormaliser(),
                HKQuantityType(.heartRate): HKHeartRateNormaliser()
            ]
            
            return HKManager(anchorStorage: anchorStorage, normalisers: normalisers, processor: processor)
        }
        
        // Register SensorManager
        await container.register(SensorManagerProtocol.self) { container in
            let storage = UserDefaultsStorage<Set<SahhaSensor>>(key: "sensors")
            let healthKitManager = try await container.resolve(HKManagerProtocol.self)
            return SensorManager(storage: storage, healthKitManager: healthKitManager)
        }
        
        // Start lifecycle observer
        do {
            let lifecycleObserver = try await container.resolve(LifecycleObserverProtocol.self)
            await lifecycleObserver.startObserving()
        } catch {
            throw SahhaError.lifecycleObserverResolutionFailed(underlyingError: error)
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
    
    func getDeviceInfoManager() async throws -> DeviceInfoManagerProtocol {
        try await resolveService(DeviceInfoManagerProtocol.self)
    }
    
    func getDemographicManager() async throws -> DemographicManagerProtocol {
        try await resolveService(DemographicManagerProtocol.self)
    }
    
    func getHealthKitManager() async throws -> HKManagerProtocol {
        try await resolveService(HKManagerProtocol.self)
    }
    
    func getSensorManager() async throws -> SensorManagerProtocol {
        try await resolveService(SensorManagerProtocol.self)
    }
    
    // MARK: Helpers
    
    func getCurrentSettings() -> SahhaSettings? {
        return cachedSettings
    }
    
    func isServiceConfigured() -> Bool {
        return isConfigured
    }
    
    func reset() async {
        await container.dispose()
        isConfigured = false
        cachedSettings = nil
        print("Sahha services reset")
    }
    
    func rebuild() async throws {
        guard let settings = cachedSettings else {
            throw SahhaError.notConfigured
        }
        await reset()
        try await configure(with: settings)
        print("Sahha services rebuilt from cached settings")
    }
}
