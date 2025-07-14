import HealthKit

protocol HKAuthorizationManager: Sendable {
    func requestAuthorization(for types: Set<HKObjectType>) async throws
    func isAuthorized(for type: HKObjectType) async throws -> Bool
    func getAuthorizationStatus(for types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus
}

final class HKAuthorizationManagerImpl: HKAuthorizationManager {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func requestAuthorization(for types: Set<HKObjectType>) async throws {
        try await healthStore.requestAuthorization(toShare: [], read: types)
    }

    func isAuthorized(for type: HKObjectType) async throws -> Bool {
        try await healthStore.statusForAuthorizationRequest(toShare: [], read: [type]) == .unnecessary
    }

    func getAuthorizationStatus(for types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        try await healthStore.statusForAuthorizationRequest(toShare: [], read: types)
    }
}
