protocol Disposable: Sendable {
    func dispose()
}

final actor DIContainer {
    static let shared = DIContainer()
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    private var disposables: [String: Disposable] = [:]

    private init() {}

    func register<T: Sendable>(_ factory: @escaping () -> T) {
        let key = String(describing: T.self)
        factories[key] = factory
    }

    func registerSingleton<T: Sendable>(_ instance: T) {
        let key = String(describing: T.self)
        services[key] = instance
        if let disposable = instance as? Disposable {
            disposables[key] = disposable
        }
    }

    func resolve<T: Sendable>() -> T {
        let key = String(describing: T.self)
        if let instance = services[key] as? T {
            return instance
        } else if let factory = factories[key] as? () -> T {
            return factory()
        } else {
            fatalError("No registration for \(key)")
        }
    }

    func dispose(_ type: any Any.Type) {
        let key = String(describing: type)
        if let disposable = disposables[key] {
            disposable.dispose()
            services.removeValue(forKey: key)
            disposables.removeValue(forKey: key)
        }
    }

    func disposeAll() {
        for disposable in disposables.values {
            disposable.dispose()
        }
        services.removeAll()
        disposables.removeAll()
    }
}
