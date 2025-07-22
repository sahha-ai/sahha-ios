import Foundation

protocol SensorManager: Sendable {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func resumeSensors() async throws
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample]
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat]
}
