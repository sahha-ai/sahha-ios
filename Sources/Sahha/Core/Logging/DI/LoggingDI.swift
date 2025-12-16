enum LoggingDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(ErrorLoggingServiceProtocol.self) { container in
            ErrorLoggingService(
                apiClient: try await container.resolve(APIClientProtocol.self),
            )
        }
        await container.register(ErrorLoggerProtocol.self) { container in
            ErrorLogger(
                errorLoggingService: try await container.resolve(ErrorLoggingServiceProtocol.self),
                deviceInfoBuilder: try await container.resolve(DeviceInfoBuilderProtocol.self),
                circuitBreaker: try? await container.resolve(CircuitBreaker.self)
            )
        }
    }
}
