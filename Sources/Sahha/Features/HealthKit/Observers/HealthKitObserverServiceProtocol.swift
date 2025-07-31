import HealthKit

protocol HealthKitObserverServiceProtocol: Sendable, Disposable {
    func startObservers(for sensors: Set<SahhaSensor>, handler: @escaping HealthKitObserverHandler) async throws
    func stopObservers(for sensors: Set<SahhaSensor>) async throws
    func enableBackgroundDelivery(for sensors: Set<SahhaSensor>) async throws
    func disableBackgroundDelivery(for sensors: Set<SahhaSensor>) async throws
}
