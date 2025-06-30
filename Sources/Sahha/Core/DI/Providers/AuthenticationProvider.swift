struct AuthenticationProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(AuthenticationServiceProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            return AuthenticationService(apiService: apiService)
        }
        await container.registerSingleton(TokenManagerProtocol.self) { container in
            let logger = try await container.resolve(LoggerProtocol.self)
            let apiService = try await container.resolve(APIServiceProtocol.self)
            let authService = try await container.resolve(AuthenticationServiceProtocol.self)
            let tokenManager = await TokenManager(logger: logger, authService: authService)
            let authInterceptor = AuthenticationInterceptor(tokenManager: tokenManager)
            await apiService.registerInterceptor(authInterceptor)
            return tokenManager
        }
    }
}
