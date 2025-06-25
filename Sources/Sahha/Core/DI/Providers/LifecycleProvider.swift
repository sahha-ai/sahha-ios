struct LifecycleProvider: ServiceProvider {
    public func registerServices(in container: DIContainer) async {
        await container.registerSingleton(LifecycleObserverProtocol.self) { container in
            LifecycleObserver()
        }
    }
}

