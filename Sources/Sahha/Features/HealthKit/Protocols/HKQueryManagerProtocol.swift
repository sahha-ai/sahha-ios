import HealthKit

protocol HKQueryManagerProtocol: Actor, Sendable, DisposableAsync {
    func enableBackgroundDelivery(for type: HKObjectType) async throws
    func disableBackgroundDelivery(for type: HKObjectType) async throws
    func startObserverQuery(for type: HKObjectType) async
    func stopObserverQuery(for type: HKObjectType) async
}
