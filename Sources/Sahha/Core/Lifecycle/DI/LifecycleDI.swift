enum LifecycleDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(LifecycleObserverProtocol.self) { _ in
            LifecycleObserver()
        }
    }
}
