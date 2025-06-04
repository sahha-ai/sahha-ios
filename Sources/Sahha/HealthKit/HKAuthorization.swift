import HealthKit

final actor HKAuthorization {
    private let healthStore = HKHealthStore()

    func requestAuthorization(for types: Set<HKSampleType>) async -> HKAuthorizationRequestStatus {
        do {
            try await healthStore.requestAuthorization(toShare: [], read: types)
            return await statusForAuthorizationRequest(for: types)
        } catch {
            return .unknown
        }
    }
    
    func statusForAuthorizationRequest(for types: Set<HKSampleType>) async -> HKAuthorizationRequestStatus {
        do {
            return try await healthStore.statusForAuthorizationRequest(toShare: [], read: types)
        } catch {
            return .unknown
        }
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }
}
