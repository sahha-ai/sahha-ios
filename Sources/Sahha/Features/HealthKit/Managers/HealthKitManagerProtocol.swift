import HealthKit

protocol HealthKitManagerProtocol: Sendable {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func resumeSensors() async
    func querySensors() async -> PostSensorDataResult
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat]
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample]
    func getDemographic() async throws -> SahhaDemographic
    func postInsights() async
}
