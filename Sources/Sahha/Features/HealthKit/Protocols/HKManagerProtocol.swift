import HealthKit

protocol HKManagerProtocol: Sendable, DisposableAsync {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func disableSensors(_ sensors: Set<SahhaSensor>) async throws
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [HKSample]
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [HKStatistics]
}
