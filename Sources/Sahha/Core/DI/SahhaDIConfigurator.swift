final actor SahhaDIConfigurator: Sendable {
    private let container: DIContainer
    private var settings: SahhaSettings?
    
    init(container: DIContainer = .shared) {
        self.container = container
    }
    
    func configure(with settings: SahhaSettings) async {
        await container.disposeAll()
        await registerServices(settings)
    }
    
    func reRegisterServices() async {
        guard let settings = settings else {
            fatalError("SahhaSettings not available for re-registration")
        }
        await registerServices(settings)
    }
    
    private func registerServices(_ settings: SahhaSettings) async {
        let apiService = APIService(baseURL: settings.environment.baseURL)
        await container.registerSingleton(apiService as APIServiceProtocol)
        await container.registerSingleton(AuthenticationService(apiService: apiService) as AuthenticationServiceProtocol)
        await container.registerSingleton(TokenManager() as TokenManagerProtocol)
    }
    
    func dispose(_ type: any Any.Type) async {
        await container.dispose(type)
    }
    
    func disposeAll() async {
        await container.disposeAll()
    }
    
    func resolve<T: Sendable>() async -> T {
        await container.resolve()
    }
}
