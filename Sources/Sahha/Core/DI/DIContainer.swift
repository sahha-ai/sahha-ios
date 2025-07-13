protocol Disposable {
    func dispose() async
}

final actor DIContainer {
    private typealias Factory = (DIContainer) async throws -> Sendable

    private var factories: [ObjectIdentifier: Factory] = [:]
    private var instances: [ObjectIdentifier: Sendable] = [:]

    func register<T: Sendable>(
        _ type: T.Type = T.self,
        factory: @escaping @Sendable (DIContainer) async throws -> T
    ) {
        factories[ObjectIdentifier(type)] = factory
    }

    func resolve<T: Sendable>(
        _ type: T.Type = T.self
    ) async throws -> T {
        let key = ObjectIdentifier(type)

        if let cached = instances[key] as? T {
            return cached
        }

        guard let make = factories[key] else {
            fatalError("No registration for \(type)")
        }

        let created = try await make(self) as! T
        instances[key] = created
        return created
    }

    func reset() async {
        for instance in instances.values {
            if let d = instance as? Disposable { await d.dispose() }
        }
        factories.removeAll()
        instances.removeAll()
    }
}
