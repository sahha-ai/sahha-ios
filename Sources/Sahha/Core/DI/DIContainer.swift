final actor DIContainer {
    typealias Factory = @Sendable (DIContainer) async throws -> Sendable

    private var factories: [ObjectIdentifier: Factory] = [:]
    private var instances: [ObjectIdentifier: Sendable] = [:]
    private var inFlight: [ObjectIdentifier: Task<Sendable, Error>] = [:]
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

        // Dedup concurrent/reentrant resolutions: a second resolve of the same
        // type joins the in-flight construction instead of building a duplicate
        // "singleton". Without this, the await on the factory lets the actor
        // re-enter and create multiple instances of the same registration.
        if let existing = inFlight[key] {
            return try await existing.value as! T
        }

        guard let factory = factories[key] else {
            throw SahhaError(message: "Dependency \(type) is not registered")
        }

        let task = Task { try await factory(self) }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let instance = try await task.value
        if let disposable = instance as? Disposable {
            disposables.append(disposable)
        }
        instances[key] = instance
        return instance as! T
    }

    func reset() async {
        for disposable in disposables {
            await disposable.dispose()
        }
        disposables.removeAll()
        factories.removeAll()
        instances.removeAll()
        inFlight.removeAll()
    }
}
