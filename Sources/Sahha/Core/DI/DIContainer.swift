import Foundation

protocol Disposable: Sendable {
    func dispose()
}

protocol DisposableActor: Sendable {
    func dispose() async
}

enum DIScope {
    case singleton
    case transient
    case scoped
}

enum DIError: Error, LocalizedError {
    case serviceNotRegistered(String)
    case circularDependency(String)
    case invalidFactory
    
    var errorDescription: String {
        switch self {
        case .serviceNotRegistered(let service):
            return "Service \(service) not registered."
        case .circularDependency(let dependency):
            return "Circular dependency detected for \(dependency)."
        case .invalidFactory:
            return "Invalid factory provided."
        }
    }
}

// TODO: Fix factory resolution errors "Failed to resolve LifecycleObserver: invalidFactory"

// TODO: Actually dispose DisposableActor - no reason to store disposables/disposable actors can instance check on clean up.

actor DIContainer {
    static let shared = DIContainer()
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    private var disposables: [String: Disposable] = [:]
    private var scopes: [String: DIScope] = [:]
    private var resolutionStack: Set<String> = []
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register a singleton service
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        services[key] = instance
        scopes[key] = .singleton
        
        if let disposable = instance as? Disposable {
            disposables[key] = disposable
        }
    }
    
    /// Register a factory for transient services
    func register<T>(_ type: T.Type, scope: DIScope = .transient, factory: @escaping @Sendable () -> T) {
        let key = String(describing: type)
        factories[key] = factory
        scopes[key] = scope
        
        // For singleton scope, create and store the instance immediately
        if scope == .singleton {
            let instance = factory()
            services[key] = instance
            
            if let disposable = instance as? Disposable {
                disposables[key] = disposable
            }
        }
    }
    
    /// Register with dependency resolution
    func register<T: Sendable>(_ type: T.Type, scope: DIScope = .transient, factory: @escaping @Sendable (DIContainer) async -> T) {
        let key = String(describing: type)
        
        let wrappedFactory: @Sendable () -> Any = {
            Task {
                await factory(self)
            }
        }
        
        factories[key] = wrappedFactory
        scopes[key] = scope
    }
    
    /// Register with dependency resolution (throwing async)
    func register<T: Sendable>(_ type: T.Type, scope: DIScope = .transient, factory: @escaping @Sendable (DIContainer) async throws -> T) {
        let key = String(describing: type)
        
        let wrappedFactory: @Sendable () -> Any = {
            Task {
                try await factory(self)
            }
        }
        
        factories[key] = wrappedFactory
        scopes[key] = scope
    }
    
    // MARK: - Resolution
    
    /// Resolve a service synchronously
    func resolve<T>(_ type: T.Type) throws -> T {
        let key = String(describing: type)
        
        // Check for circular dependency
        guard !resolutionStack.contains(key) else {
            throw DIError.circularDependency(key)
        }
        
        // Check singleton cache first
        if let service = services[key] as? T {
            return service
        }
        
        // Get factory
        guard let factory = factories[key] else {
            throw DIError.serviceNotRegistered(key)
        }
        
        // Track resolution to prevent circular dependencies
        resolutionStack.insert(key)
        defer { resolutionStack.remove(key) }
        
        guard let instance = factory() as? T else {
            throw DIError.invalidFactory
        }
        
        // Cache if singleton
        if scopes[key] == .singleton {
            services[key] = instance
            
            if let disposable = instance as? Disposable {
                disposables[key] = disposable
            }
        }
        
        return instance
    }
    
    /// Resolve a service asynchronously (for async factories)
    func resolveAsync<T: Sendable>(_ type: T.Type) async throws -> T {
        let key = String(describing: type)
        
        // Check for circular dependency
        guard !resolutionStack.contains(key) else {
            throw DIError.circularDependency(key)
        }
        
        // Check singleton cache first
        if let service = services[key] as? T {
            return service
        }
        
        // Get factory
        guard let factory = factories[key] else {
            throw DIError.serviceNotRegistered(key)
        }
        
        // Track resolution to prevent circular dependencies
        resolutionStack.insert(key)
        defer { resolutionStack.remove(key) }
        
        let factoryResult = factory()
        
        // Handle async factory results
        if let task = factoryResult as? Task<T, Never> {
            let instance = await task.value
            
            // Cache if singleton
            if scopes[key] == .singleton {
                services[key] = instance
                
                if let disposable = instance as? Disposable {
                    disposables[key] = disposable
                }
            }
            
            return instance
        }
        
        // Handle sync factory results
        guard let instance = factoryResult as? T else {
            throw DIError.invalidFactory
        }
        
        // Cache if singleton
        if scopes[key] == .singleton {
            services[key] = instance
            
            if let disposable = instance as? Disposable {
                disposables[key] = disposable
            }
        }
        
        return instance
    }
    
    /// Optional resolution - returns nil if not registered
    func resolveOptional<T>(_ type: T.Type) -> T? {
        return try? resolve(type)
    }
    
    /// Async optional resolution
    func resolveOptionalAsync<T: Sendable>(_ type: T.Type) async -> T? {
        return try? await resolveAsync(type)
    }
    
    // MARK: - Management
    
    /// Check if a service is registered
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        return services[key] != nil || factories[key] != nil
    }
    
    /// Remove a service registration
    func unregister<T>(_ type: T.Type) {
        let key = String(describing: type)
        
        // Dispose if needed
        if let disposable = disposables[key] {
            disposable.dispose()
            disposables.removeValue(forKey: key)
        }
        
        services.removeValue(forKey: key)
        factories.removeValue(forKey: key)
        scopes.removeValue(forKey: key)
    }
    
    /// Dispose all disposable services
    func disposeAll() {
        for disposable in disposables.values {
            disposable.dispose()
        }
        disposables.removeAll()
    }
    
    /// Clear all registrations
    func reset() {
        disposeAll()
        services.removeAll()
        factories.removeAll()
        scopes.removeAll()
        resolutionStack.removeAll()
    }
    
    /// Get registration info for debugging
    func getRegisteredServices() -> [String: DIScope] {
        return scopes
    }
}

// MARK: - Convenience Extensions

extension DIContainer {
    /// Register a singleton with lazy initialization
    func registerSingleton<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        register(type, scope: .singleton, factory: factory)
    }
    
    /// Register a singleton with async dependency resolution
    func registerSingleton<T: Sendable>(_ type: T.Type, factory: @escaping @Sendable (DIContainer) async throws -> T) {
        register(type, scope: .singleton, factory: factory)
    }
    
    /// Register a transient service
    func registerTransient<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        register(type, scope: .transient, factory: factory)
    }
    
    /// Register multiple services at once
    func registerServices(@ServiceRegistrationBuilder _ builder: () -> [ServiceRegistration]) {
        let registrations = builder()
        for registration in registrations {
            registration.register(self)
        }
    }
}

// MARK: - Service Registration Builder

@resultBuilder
struct ServiceRegistrationBuilder {
    static func buildBlock(_ components: ServiceRegistration...) -> [ServiceRegistration] {
        return components
    }
}

struct ServiceRegistration {
    let register: (DIContainer) -> Void
    
    static func singleton<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) -> ServiceRegistration {
        ServiceRegistration { container in
            Task {
                await container.registerSingleton(type, factory: factory)
            }
        }
    }
    
    static func transient<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) -> ServiceRegistration {
        ServiceRegistration { container in
            Task {
                await container.registerTransient(type, factory: factory)
            }
        }
    }
}
