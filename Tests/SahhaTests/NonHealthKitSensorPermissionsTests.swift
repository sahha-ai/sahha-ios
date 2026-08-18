import Testing
import Foundation
import HealthKit
@testable import Sahha

/// Coverage for the "Health data types not specified." fix: some SahhaSensor cases
/// (.device_lock, and Android-only types like .basal_metabolic_rate) have no
/// HealthKit backing, so a sensor set composed entirely of them used to throw from
/// enableSensors/getSensorStatus on every call — the SDK's top production error.
/// The permissions service must treat them as a graceful no-op instead, the way
/// hasPermissions(for:) always has.
@Suite("NonHealthKitSensorPermissions")
struct NonHealthKitSensorPermissionsTests {

    // MARK: - HealthKitPermissionsService

    @Test("requestPermissions with only non-HealthKit sensors succeeds without consulting the store")
    func requestPermissionsIsNoOp() async throws {
        let store = RecordingHealthStore()
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 5)

        try await service.requestPermissions(for: [.device_lock])
        try await service.requestPermissions(for: [.device_lock, .basal_metabolic_rate])

        #expect(store.authorizationRequests.isEmpty)
    }

    @Test("getPermissionsStatus with only non-HealthKit sensors returns .unnecessary without consulting the store")
    func statusIsUnnecessary() async throws {
        let store = RecordingHealthStore()
        // Would be returned if the store were (wrongly) consulted.
        store.statusToReturn = .shouldRequest
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 5)

        let status = try await service.getPermissionsStatus(for: [.device_lock])

        #expect(status == .unnecessary)
        #expect(store.statusRequests.isEmpty)
    }

    @Test("Mixed sets request authorization for only the HealthKit-backed types")
    func mixedSetRequestsBackedTypes() async throws {
        let store = RecordingHealthStore()
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 5)

        try await service.requestPermissions(for: [.steps, .device_lock])

        #expect(store.authorizationRequests == [SahhaSensor.steps.hkPermissions])
    }

    @Test("Mixed sets pass the store's status through for the HealthKit-backed types")
    func mixedSetStatusPassesThrough() async throws {
        let store = RecordingHealthStore()
        store.statusToReturn = .shouldRequest
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 5)

        let status = try await service.getPermissionsStatus(for: [.steps, .device_lock])

        #expect(status == .shouldRequest)
        #expect(store.statusRequests == [SahhaSensor.steps.hkPermissions])
    }

    @Test("Empty sensor sets still throw")
    func emptySetStillThrows() async {
        let service = HealthKitPermissionsService(healthStore: RecordingHealthStore(), requestTimeout: 5)

        await #expect(throws: SahhaError.self) {
            try await service.requestPermissions(for: [])
        }
        await #expect(throws: SahhaError.self) {
            _ = try await service.getPermissionsStatus(for: [])
        }
    }

    @Test("hasPermissions stays false for non-HealthKit sensors so internal HK queries skip them")
    func hasPermissionsStaysFalse() async throws {
        let store = RecordingHealthStore()
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 5)

        #expect(try await service.hasPermissions(for: .device_lock) == false)
        #expect(store.statusRequests.isEmpty)
    }

    // MARK: - HealthKitManager end-to-end (the production symptom)

    @Test("enableSensors([.device_lock]) succeeds and starts data collection")
    func enableDeviceLockSucceeds() async throws {
        let harness = ManagerHarness()

        try await harness.manager.enableSensors([.device_lock])

        #expect(try await harness.sensorStore.getSensors() == [.device_lock])
        #expect(harness.dataLogCoordinator.startedSensors == [.device_lock])
    }

    @Test("getSensorStatus([.device_lock]) is .pending before enabling and .enabled after")
    func deviceLockStatusLifecycle() async throws {
        let harness = ManagerHarness()

        #expect(try await harness.manager.getSensorStatus([.device_lock]) == .pending)

        try await harness.manager.enableSensors([.device_lock])

        #expect(try await harness.manager.getSensorStatus([.device_lock]) == .enabled)
    }
}

// MARK: - Mocks (self-contained for this suite)

/// A HealthKitManager wired with a real permissions service (over the recording
/// store) and inert stubs for everything else.
private struct ManagerHarness {
    let sensorStore = InMemorySensorStore()
    let dataLogCoordinator = StubDataLogCoordinator()
    let manager: HealthKitManager

    init() {
        manager = HealthKitManager(
            permissions: HealthKitPermissionsService(healthStore: RecordingHealthStore(), requestTimeout: 5),
            sensorStore: sensorStore,
            dataLogCoordinator: dataLogCoordinator,
            tagCoordinator: StubTagCoordinator(),
            statCoordinator: StubStatCoordinator(),
            sampleCoordinator: StubSampleCoordinator(),
            demographicService: StubDemographicService(),
            activitySummaryUploader: StubActivitySummaryUploader(),
            logger: StubErrorLogger()
        )
    }
}

private actor InMemorySensorStore: SensorStoreProtocol {
    private var sensors: Set<SahhaSensor> = []
    private var statuses: [SahhaSensor: SahhaSensorStatus] = [:]

    func setSensors(_ sensors: Set<SahhaSensor>) throws { self.sensors = sensors }
    func getSensors() throws -> Set<SahhaSensor> { sensors }
    func hasSensor(_ sensor: SahhaSensor) -> Bool { sensors.contains(sensor) }
    func setSensorStatuses(_ statuses: [SahhaSensor: SahhaSensorStatus]) { self.statuses = statuses }
    func getSensorStatuses() -> [SahhaSensor: SahhaSensorStatus] { statuses }
}

private final class StubDataLogCoordinator: HealthKitDataLogCoordinatorProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _started: Set<SahhaSensor> = []

    var startedSensors: Set<SahhaSensor> {
        lock.lock()
        defer { lock.unlock() }
        return _started
    }

    func startDataLogCollection(for sensors: Set<SahhaSensor>) async throws {
        record(sensors)
    }

    private func record(_ sensors: Set<SahhaSensor>) {
        lock.lock()
        _started.formUnion(sensors)
        lock.unlock()
    }

    func stopDataLogCollection(for sensors: Set<SahhaSensor>) async throws {}
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

private final class StubTagCoordinator: HealthKitTagCoordinatorProtocol, @unchecked Sendable {
    func startTagCollection(for sensors: Set<SahhaSensor>) async throws {}
    func stopTagCollection(for sensors: Set<SahhaSensor>) async throws {}
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

private struct StubStatCoordinator: HealthKitSahhaStatCoordinatorProtocol {
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] { [] }
}

private struct StubSampleCoordinator: HealthKitSahhaSampleCoordinatorProtocol {
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] { [] }
}

private struct StubDemographicService: HealthKitDemographicServiceProtocol {
    func fetchGender() async throws -> HKBiologicalSex { .notSet }
    func fetchDateOfBirth() async throws -> Date? { nil }
}

private struct StubActivitySummaryUploader: HealthKitActivitySummaryUploaderProtocol {
    func postInsights() async {}
}

private struct StubErrorLogger: ErrorLoggerProtocol {
    func postError(_ error: Error, file: StaticString, function: StaticString, line: UInt) {}
}
