import Foundation

protocol HealthKitSahhaStatCoordinatorProtocol: Sendable {
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat]
}
