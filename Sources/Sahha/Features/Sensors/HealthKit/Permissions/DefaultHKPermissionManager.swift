import HealthKit

final class DefaultHKPermissionManager: HKPermissionManager {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }

    func requestPermissions(for sensors: Set<SahhaSensor>) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        let typesToRead = Set(sensors.compactMap(\.hkPermissions).flatMap { $0 })
        guard !typesToRead.isEmpty else { return }
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }

    func permissionStatus(for sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        let typesToRead = Set(sensors.compactMap(\.hkPermissions).flatMap { $0 })
        guard !typesToRead.isEmpty else { return .unavailable }
        let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: typesToRead)
        if case .unnecessary = status {
            return .enabled
        }
        return .pending
    }

    func hasPermissions(for sensor: SahhaSensor) async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        let permissions = sensor.hkPermissions
        guard !permissions.isEmpty else { return false }
        let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: permissions)
        return status == .unnecessary
    }

}
