protocol HKObserverProviding: Actor {
    func startObserving(sensor: SahhaSensor, handler: @escaping @Sendable (SahhaSensor) -> Void) async throws
    func stopObserving(sensor: SahhaSensor) async throws
    func enableBackgroundDelivery(for sensor: SahhaSensor) async throws
    func disableBackgroundDelivery(for sensor: SahhaSensor) async throws
    func stopAllObservers() async throws
    func disableAllBackgroundDelivery() async throws
}
