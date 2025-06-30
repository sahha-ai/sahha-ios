struct LifecycleProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(LifecycleObserverProtocol.self) { container in
            let logger = try await container.resolve(LoggerProtocol.self)
            return LifecycleObserver(logger: logger)
        }
    }
}

