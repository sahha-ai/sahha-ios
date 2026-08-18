import HealthKit

protocol HealthKitManagerProtocol: Sendable {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func resumeSensors() async
    /// Re-arms collection for `sensors` only, intersected with a fresh store read
    /// at arm time so a concurrent narrowing `enableSensors` can never resurrect
    /// a torn-down sensor. Each side (data-log, tag) arms independently; failures
    /// are posted, never thrown.
    func resumeSensors(for sensors: Set<SahhaSensor>) async
    func querySensors() async -> PostSensorDataResult
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat]
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample]
    func getDemographic() async throws -> SahhaDemographic
    func postInsights() async
}
