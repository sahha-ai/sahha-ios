final actor DIContainer {
    public let sahhaSettings: SahhaSettings
    private var registrations: [String: ServiceEntry] = [:]
    private var disposables: [any Sendable] = []
    
    init(sahhaSettings: SahhaSettings) {
        self.sahhaSettings = sahhaSettings
    }
    
    func register<T: Sendable>(_ type: T.Type, lifetime: ServiceLifetime = .transient, factory: @escaping @Sendable (DIContainer) async throws -> T) {
        let key = String(describing: type)
        let wrappedFactory: @Sendable (DIContainer) async throws -> any Sendable = { container in
            try await factory(container)
        }
        registrations[key] = ServiceEntry(factory: wrappedFactory, lifetime: lifetime, instance: nil)
    }
    
    func registerSingleton<T: Sendable>(_ type: T.Type, factory: @escaping @Sendable (DIContainer) async throws -> T) {
        register(type, lifetime: .singleton, factory: factory)
    }
    
    func resolve<T: Sendable>(_ type: T.Type) async throws -> T {
        let key = String(describing: type)
        
        guard let entry = registrations[key] else {
            throw DIError.serviceNotRegistered(key)
        }
        
        switch entry.lifetime {
        case .transient:
            guard let instance = try await entry.factory(self) as? T else {
                throw DIError.invalidFactoryResult(key)
            }
            trackDisposable(instance)
            return instance
        case .singleton:
            if let instance = entry.instance as? T {
                return instance
            }
            guard let instance = try await entry.factory(self) as? T else {
                throw DIError.invalidFactoryResult(key)
            }
            var mutableEntry = entry
            mutableEntry.instance = instance
            registrations[key] = mutableEntry
            trackDisposable(instance)
            return instance
        }
    }
    
    func registerProvider(_ provider: ServiceProvider) async throws {
        try await provider.registerServices(in: self)
    }
    
    func reset() async throws {
        var errors: [Error] = []
        for disposable in disposables {
            do {
                if let syncDisposable = disposable as? Disposable {
                    try syncDisposable.dispose()
                } else if let asyncDisposable = disposable as? DisposableAsync {
                    try await asyncDisposable.dispose()
                }
            } catch {
                errors.append(error)
            }
        }
        
        disposables.removeAll()
        registrations.removeAll()
        
        if !errors.isEmpty {
            throw DIError.disposalFailed(errors)
        }
    }
    
    private func trackDisposable(_ instance: Any?) {
        if let disposable = instance as? Disposable {
            disposables.append(disposable)
        } else if let asyncDisposable = instance as? DisposableAsync {
            disposables.append(asyncDisposable)
        }
    }
}
