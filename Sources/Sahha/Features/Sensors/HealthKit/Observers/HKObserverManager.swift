typealias ObserverHandlerFn = @Sendable (SahhaSensor) async throws -> Void

protocol HKObserverManager: Actor {
    func startObserving(sensors: Set<SahhaSensor>, handler: @escaping ObserverHandlerFn) async throws
    func stopObserving(sensors: Set<SahhaSensor>) async
    func stopObservingAll() async
}
