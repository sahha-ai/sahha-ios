import HealthKit

final class HealthKitDemographicService: HealthKitDemographicServiceProtocol {
    private let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }
    
    func fetchGender() throws -> HKBiologicalSex {
        try healthStore.biologicalSex().biologicalSex
    }

    func fetchDateOfBirth() async throws -> Date? {
        try healthStore.dateOfBirthComponents().date
    }
}
