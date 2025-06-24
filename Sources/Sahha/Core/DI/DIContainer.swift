import Foundation

protocol Disposable {
    func dispose()
}

protocol DisposableAsync: Sendable {
    func dispose() async
}

enum DIError: Error, LocalizedError {
    case serviceNotRegistered(type: Any.Type)
    case serviceCreationFailed(type: Any.Type, underlyingError: Error)
    case typeMismatch(expected: Any.Type, actual: any Sendable)

    var errorDescription: String? {
        switch self {
        case .serviceNotRegistered(let type):
            return "Service not registered for type: \(type)"
        case .serviceCreationFailed(let type, let underlyingError):
            return "Failed to create service for type: \(type). Underlying error: \(underlyingError)"
        case .typeMismatch(let expected, let actual):
            return "Type mismatch: expected \(expected), but got \(actual)"
        }
    }
}

actor DIContainer {
    private var factories: [ObjectIdentifier: (DIContainer) async throws -> any Sendable] = [:]
    private var instances: [ObjectIdentifier: Any] = [:]
    private var registrationOrder: [ObjectIdentifier] = []

    func register<T: Sendable>(_ type: T.Type, factory: @escaping (DIContainer) async throws -> T) {
        let key = ObjectIdentifier(type)
        if factories[key] == nil {
            registrationOrder.append(key)
        }
        factories[key] = { container in
            try await factory(container)
        }
    }

    func resolve<T: Sendable>(_ type: T.Type) async throws -> T {
        let key = ObjectIdentifier(type)
        if let instance = instances[key] as? T {
            return instance
        } else if let factory = factories[key] {
            do {
                let instance = try await factory(self)
                guard let typedInstance = instance as? T else {
                    throw DIError.typeMismatch(expected: T.self, actual: instance)
                }
                instances[key] = typedInstance
                return typedInstance
            } catch {
                throw DIError.serviceCreationFailed(type: T.self, underlyingError: error)
            }
        } else {
            throw DIError.serviceNotRegistered(type: T.self)
        }
    }

    func dispose() async {
        for key in registrationOrder.reversed() {
            if let instance = instances[key] as? Disposable {
                instance.dispose()
            }
            if let instance = instances[key] as? DisposableAsync {
                await instance.dispose()
            }
        }
        instances.removeAll()
        factories.removeAll()
        registrationOrder.removeAll()
    }
}
