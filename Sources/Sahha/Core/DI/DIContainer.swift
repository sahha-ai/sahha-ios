final actor DIContainer {
    typealias Factory = @Sendable (DIContainer) async throws -> Sendable

    private var factories: [ObjectIdentifier: Factory] = [:]
    private var instances: [ObjectIdentifier: Sendable] = [:]
    private var inFlight: [ObjectIdentifier: Task<Sendable, Error>] = [:]
    private var disposables: [Disposable] = []
    /// Latched by `reset()` — a container is single-use, torn down exactly once
    /// (deauthentication). Afterwards resolutions fail as "not configured",
    /// never as a confusing missing-registration error from a half-emptied
    /// registry, and an instance finishing construction mid-reset is disposed
    /// rather than leaked undisposed into a dead container.
    private var isReset = false

    private static var notConfiguredError: SahhaError {
        SahhaError(message: "Sahha is not configured. Please call `Sahha.configure(...)` first.")
    }

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
        guard !isReset else { throw Self.notConfiguredError }
        let key = ObjectIdentifier(type)

        if let singleton = instances[key] as? T {
            return singleton
        }

        // Dedup concurrent/reentrant resolutions: a second resolve of the same
        // type joins the in-flight construction instead of building a duplicate
        // "singleton". Without this, the await on the factory lets the actor
        // re-enter and create multiple instances of the same registration.
        if let existing = inFlight[key] {
            let value = try await existing.value
            // The starter disposes an instance whose construction straddled
            // reset; joiners only need to stop handing it out.
            guard !isReset else { throw Self.notConfiguredError }
            return value as! T
        }

        guard let factory = factories[key] else {
            throw SahhaError(message: "Dependency \(type) is not registered")
        }

        let task = Task { try await factory(self) }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        let instance = try await task.value
        guard !isReset else {
            // Reset interleaved with this construction: its dispose pass could
            // not see the instance, so tear it down here instead of caching it
            // into a dead container.
            if let disposable = instance as? Disposable {
                await disposable.dispose()
            }
            throw Self.notConfiguredError
        }
        if let disposable = instance as? Disposable {
            disposables.append(disposable)
        }
        instances[key] = instance
        return instance as! T
    }

    func reset() async {
        isReset = true
        for disposable in disposables {
            await disposable.dispose()
        }
        disposables.removeAll()
        factories.removeAll()
        instances.removeAll()
        inFlight.removeAll()
    }
}
