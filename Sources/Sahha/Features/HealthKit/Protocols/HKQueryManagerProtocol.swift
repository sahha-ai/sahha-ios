import HealthKit

protocol HKQueryManagerProtocol: Actor, Sendable {
    func enableBackgroundDelivery(for type: HKObjectType) async throws
    func disableBackgroundDelivery(for type: HKObjectType) async throws
    func startObserverQuery(for type: HKObjectType) async
    func stopObserverQuery(for type: HKObjectType) async
    func stopAllAndClear() async throws
    func querySamples(for type: HKSampleType, startDateTime: Date, endDateTime: Date) async throws -> [HKSample]
    func queryStats(for type: HKObjectType, startDateTime: Date, endDateTime: Date) async throws -> [HKStatistics]
}
