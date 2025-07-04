struct LoggingProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(LoggingServiceProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            return LoggingService(apiService: apiService)
        }
        await container.registerSingleton(LoggerProtocol.self) { container in
            let apiService = try await container.resolve(APIServiceProtocol.self)
            let loggingService = try await container.resolve(LoggingServiceProtocol.self)
            let deviceInformation = try await container.resolve(DeviceInformation.self)
            let logger = Logger(loggingService: loggingService, deviceInformation: deviceInformation)
            let errorLoggingInterceptor = ErrorLoggingInterceptor(logger: logger)
            await apiService.registerInterceptor(errorLoggingInterceptor)
            return logger
        }
    }
}
