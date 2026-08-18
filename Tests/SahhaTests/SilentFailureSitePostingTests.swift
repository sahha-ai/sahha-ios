import Testing
import Foundation
import HealthKit
@testable import Sahha

// MARK: - Throwing doubles
//
// Each test creates its marker SahhaError at a captured line, so assertions can pin
// the recorded error's provenance to the real throw site — not just a non-zero count.

/// Sensor store whose reads fail with an injected error.
private actor ThrowingSensorStore: SensorStoreProtocol {
    private let error: SahhaError
    init(error: SahhaError) { self.error = error }

    func setSensors(_ sensors: Set<SahhaSensor>) throws { throw error }
    func getSensors() throws -> Set<SahhaSensor> { throw error }
    func hasSensor(_ sensor: SahhaSensor) -> Bool { false }
    func setSensorStatuses(_ statuses: [SahhaSensor: SahhaSensorStatus]) {}
    func getSensorStatuses() -> [SahhaSensor: SahhaSensorStatus] { [:] }
}

private actor ThrowingDataLogCoordinator: HealthKitDataLogCoordinatorProtocol {
    private let error: SahhaError
    init(error: SahhaError) { self.error = error }

    func startDataLogCollection(for sensors: Set<SahhaSensor>) async throws { throw error }
    func stopDataLogCollection(for sensors: Set<SahhaSensor>) async throws { throw error }
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

// MARK: - Inert doubles (self-contained for this file)

private actor InertDataLogCoordinator: HealthKitDataLogCoordinatorProtocol {
    func startDataLogCollection(for sensors: Set<SahhaSensor>) async throws {}
    func stopDataLogCollection(for sensors: Set<SahhaSensor>) async throws {}
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

private actor InertTagCoordinator: HealthKitTagCoordinatorProtocol {
    func startTagCollection(for sensors: Set<SahhaSensor>) async throws {}
    func stopTagCollection(for sensors: Set<SahhaSensor>) async throws {}
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

private struct InertStatCoordinator: HealthKitSahhaStatCoordinatorProtocol {
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] { [] }
}

private struct InertSampleCoordinator: HealthKitSahhaSampleCoordinatorProtocol {
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] { [] }
}

private struct InertDemographicService: HealthKitDemographicServiceProtocol {
    func fetchGender() async throws -> HKBiologicalSex { .notSet }
    func fetchDateOfBirth() async throws -> Date? { nil }
}

private struct InertActivitySummaryUploader: HealthKitActivitySummaryUploaderProtocol {
    func postInsights() async {}
}

private struct InertSampleQueryService: HealthKitSampleQueryServiceProtocol {
    func runSampleQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKSample] { [] }
}

private func makeManager(
    sensorStore: SensorStoreProtocol,
    dataLogCoordinator: HealthKitDataLogCoordinatorProtocol = InertDataLogCoordinator(),
    tagCoordinator: HealthKitTagCoordinatorProtocol = InertTagCoordinator(),
    logger: ErrorLoggerProtocol
) -> HealthKitManager {
    HealthKitManager(
        permissions: HealthKitPermissionsService(healthStore: RecordingHealthStore(), requestTimeout: 5),
        sensorStore: sensorStore,
        dataLogCoordinator: dataLogCoordinator,
        tagCoordinator: tagCoordinator,
        statCoordinator: InertStatCoordinator(),
        sampleCoordinator: InertSampleCoordinator(),
        demographicService: InertDemographicService(),
        activitySummaryUploader: InertActivitySummaryUploader(),
        logger: logger
    )
}

/// PRD #76, D5: the sensor pipeline's previously silent failure sites now post to the
/// error logger, asserted at module boundaries through the recording double — including
/// the provenance the posted error resolves to.
@Suite("Silent failure sites post errors")
struct SilentFailureSitePostingTests {

    // MARK: - Launch-time resume

    @Test("resumeSensors posts a store-read failure")
    func resumeSensorsPostsStoreReadFailure() async throws {
        let line = UInt(#line) + 1
        let marker = SahhaError(message: "sensor store unreadable")
        let logger = RecordingErrorLogger()
        let manager = makeManager(sensorStore: ThrowingSensorStore(error: marker), logger: logger)

        await manager.resumeSensors()

        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "sensor store unreadable")
        #expect(error.file == #fileID)
        #expect(error.line == line)
    }

    @Test("resumeSensors posts a collection-start failure")
    func resumeSensorsPostsCollectionStartFailure() async throws {
        let line = UInt(#line) + 1
        let marker = SahhaError(message: "observer registration failed")
        let storage = InMemoryStorage()
        storage.set(try JSONEncoder().encode(["sleep"]), forKey: StorageKeys.UserDefaults.sensors)
        let logger = RecordingErrorLogger()
        let manager = makeManager(
            sensorStore: SensorStore(storage: storage, key: StorageKeys.UserDefaults.sensors),
            dataLogCoordinator: ThrowingDataLogCoordinator(error: marker),
            logger: logger
        )

        await manager.resumeSensors()

        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "observer registration failed")
        #expect(error.line == line)
    }

    // MARK: - Sensor query path

    @Test("querySensors posts the store-read failure it previously only returned")
    func querySensorsPostsStoreReadFailure() async throws {
        let line = UInt(#line) + 1
        let marker = SahhaError(message: "sensor store unreadable")
        let logger = RecordingErrorLogger()
        let manager = makeManager(sensorStore: ThrowingSensorStore(error: marker), logger: logger)

        let result = await manager.querySensors()

        #expect(result.errorDescription == "sensor store unreadable")
        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.line == line)
    }

    // MARK: - Health-check listener

    @Test("The health check posts its previously swallowed store-read failure")
    func healthCheckPostsStoreReadFailure() async throws {
        let line = UInt(#line) + 1
        let marker = SahhaError(message: "sensor store unreadable")
        let observerStore = MockHealthKitObserverStore()
        let logger = RecordingErrorLogger()
        let listener = SensorHealthCheckLifecycleListener(
            sensorStore: ThrowingSensorStore(error: marker),
            observerStore: observerStore,
            healthKitManager: MockHealthKitManager(observerStore: observerStore, sensorsToRegister: []),
            logger: logger
        )

        await listener.handleLifecycleEvent(.app_foreground)

        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "sensor store unreadable")
        #expect(error.line == line)
        // The check still reports the empty result it always did.
        let result = try #require(await listener.getLatestResult())
        #expect(result.sensorsChecked.isEmpty)
    }

    @Test("The health check posts one aggregate error naming every failed sensor")
    func healthCheckPostsOneAggregateError() async throws {
        let sensorStore = MockSensorStoreForHealthCheck()
        try await sensorStore.setSensors([.heart_rate, .sleep])
        let observerStore = MockHealthKitObserverStore()   // empty: both observers missing
        let logger = RecordingErrorLogger()
        let listener = SensorHealthCheckLifecycleListener(
            sensorStore: sensorStore,
            observerStore: observerStore,
            healthKitManager: MockHealthKitManager(observerStore: observerStore, sensorsToRegister: []),
            logger: logger
        )

        await listener.handleLifecycleEvent(.app_foreground)

        // Exactly one post for two failures — per-sensor posts would be collapsed
        // to one arbitrary sensor by the logger's origin-keyed dedup.
        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "Observer re-registration failed for 2 sensor(s): heart_rate, sleep")
        let result = try #require(await listener.getLatestResult())
        #expect(result.failures.count == 2)
    }

    @Test("The aggregate names only the sensors that actually failed")
    func healthCheckAggregateNamesOnlyFailures() async throws {
        let sensorStore = MockSensorStoreForHealthCheck()
        try await sensorStore.setSensors([.heart_rate, .sleep])
        let observerStore = MockHealthKitObserverStore()
        let logger = RecordingErrorLogger()
        let listener = SensorHealthCheckLifecycleListener(
            sensorStore: sensorStore,
            observerStore: observerStore,
            // resumeSensors re-registers heart_rate; sleep stays missing.
            healthKitManager: MockHealthKitManager(observerStore: observerStore, sensorsToRegister: [.heart_rate]),
            logger: logger
        )

        await listener.handleLifecycleEvent(.app_foreground)

        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "Observer re-registration failed for 1 sensor(s): sleep")
        let result = try #require(await listener.getLatestResult())
        #expect(result.sensorsReRegistered == [.heart_rate])
        #expect(Array(result.failures.keys) == [.sleep])
    }

    // MARK: - Probe listener

    @Test("The probe posts its previously swallowed store-read failure")
    func probePostsStoreReadFailure() async throws {
        let line = UInt(#line) + 1
        let marker = SahhaError(message: "sensor store unreadable")
        let logger = RecordingErrorLogger()
        let listener = SensorProbeLifecycleListener(
            sensorStore: ThrowingSensorStore(error: marker),
            sampleQueryService: InertSampleQueryService(),
            logger: logger
        )

        await listener.handleLifecycleEvent(.app_foreground)

        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "sensor store unreadable")
        #expect(error.line == line)
    }

    // MARK: - Diagnostic report builder

    @Test("The report builder posts its store-read failure and still builds the report")
    func reportBuilderPostsStoreReadFailure() async throws {
        let line = UInt(#line) + 1
        let marker = SahhaError(message: "sensor store unreadable")
        let logger = RecordingErrorLogger()
        let builder = DiagnosticReportBuilder(
            sensorStore: ThrowingSensorStore(error: marker),
            dataLogUploader: NullDataLogUploader(),
            tagUploader: NullTagUploader(),
            storage: InMemoryStorage(),
            logger: logger
        )

        let report = await builder.buildReport()

        #expect(report.enabledSensors.isEmpty)
        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "sensor store unreadable")
        #expect(error.line == line)
    }

    @Test("The report builder posts an undecodable stored report instead of hiding it")
    func reportBuilderPostsUndecodableStoredReport() async throws {
        let storage = InMemoryStorage()
        storage.set(Data("not json".utf8), forKey: "com.sahha.diagnostic_report")
        let logger = RecordingErrorLogger()
        let builder = DiagnosticReportBuilder(
            sensorStore: MockSensorStoreForHealthCheck(),
            dataLogUploader: NullDataLogUploader(),
            tagUploader: NullTagUploader(),
            storage: storage,
            logger: logger
        )

        let report = await builder.getLatestReport()

        #expect(report == nil)
        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "Stored diagnostic report could not be decoded.")
        #expect(error.file.hasSuffix("DiagnosticReportBuilder.swift"))
        #expect(error.error is DecodingError)
    }

    // MARK: - Token store

    @Test("The token store posts its init-time keychain read failure")
    func tokenStorePostsInitTimeKeychainFailure() throws {
        let keychain = MockKeychainStorage()
        keychain.errorToThrow = NSError(domain: "keychain.test", code: -25300)
        let logger = RecordingErrorLogger()

        _ = TokenStore(storage: keychain, logger: logger)

        let posted = logger.drain()
        #expect(posted.count == 1)
        let error = try #require(posted.first?.error as? SahhaError)
        #expect(error.message == "Token store failed to read the persisted session from the keychain.")
        #expect(error.file.hasSuffix("TokenStore.swift"))
        #expect(error.function.contains("init"))
        let underlying = try #require(error.error)
        #expect((underlying as NSError).domain == "keychain.test")
    }
}
