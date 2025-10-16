import Foundation

protocol HealthKitSahhaSampleCoordinatorProtocol: Sendable {
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample]
}
