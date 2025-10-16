final actor DIContainer {
    typealias Factory = @Sendable (DIContainer) async throws -> Sendable

    private var factories: [ObjectIdentifier: Factory] = [:]
    private var instances: [ObjectIdentifier: Sendable] = [:]
    private var disposables: [Disposable] = []
    
    func register<T: Sendable>(
        _ type: T.Type = T.self,
        factory: @escaping Factory
    ) {
        let key = ObjectIdentifier(type)
        factories[key] = factory
    }

    func resolve<T: Sendable>(
        _ type: T.Type = T.self
    ) async throws -> T {
        let key = ObjectIdentifier(type)

        if let singleton = instances[key] as? T {
            return singleton
        }
        
        if let factory = factories[key] {
            let instance = try await factory(self)
            if let disposable = instance as? Disposable {
                disposables.append(disposable)
            }
            instances[key] = instance
            return instance as! T
        }

        throw SahhaError(message: "Dependency \(type) is not registered")
    }

    func reset() async {
        for disposable in disposables {
            await disposable.dispose()
        }
        disposables.removeAll()
        factories.removeAll()
        instances.removeAll()
    }
}
