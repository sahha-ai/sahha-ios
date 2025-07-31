import HealthKit

protocol HealthKitDemographicServiceProtocol: Sendable {
    func fetchGender() async throws -> HKBiologicalSex
    func fetchDateOfBirth() async throws -> Date?
}
