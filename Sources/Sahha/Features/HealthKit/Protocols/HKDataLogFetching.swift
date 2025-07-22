protocol HKDataLogFetching: Actor, Disposable {
    func start(for sensor: SahhaSensor) async throws
    func stop(for sensor: SahhaSensor) async throws
}
