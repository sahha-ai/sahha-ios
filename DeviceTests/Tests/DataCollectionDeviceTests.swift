import Foundation
import HealthKit
import Testing
@testable import Sahha

/// Data collection end to end through real HealthKit: the SDK's own permission request,
/// observer service, anchored-query pager, normalisers and anchor handling. Only the upload
/// pipeline is replaced, by a recorder, so the test reads exactly the data logs the SDK
/// would have queued for upload.
///
/// Why: the simulator unit suite mocks HealthKit, and the first-sync suite measures paging
/// cost without collecting anything inside the 30-day window. This suite checks that the
/// samples a user has actually reach the upload queue, once each, on the OS under test.
///
/// Every sample it writes is tagged and comes from this app's own source, and is deleted at
/// the end of each test. No other app's data is touched.
@Suite("Data collection through real HealthKit", .serialized)
struct DataCollectionDeviceTests {
    private let health = CollectionHealthStore.shared

    // MARK: - Permissions

    @Test("The SDK's permission request returns once the sheet is answered, with nothing left to ask", .timeLimit(.minutes(10)))
    func permissionRequestCompletes() async throws {
        try await health.authorize()
        let permissions = HealthKitPermissionsService(healthStore: health.store)
        let status = try await permissions.getPermissionsStatus(for: Set(CollectionHealthStore.sensors))
        #expect(status == .unnecessary, "HealthKit still wants to ask for some of the collected sensors after the sheet was answered.")
    }

    // MARK: - First sync and incremental sync

    @Test("A first sync collects every in-window sample once, drops older ones, and later syncs collect only new samples", .timeLimit(.minutes(5)))
    func firstSyncThenIncremental() async throws {
        try await health.authorize()
        try await health.deleteTagged()

        let now = Date()
        let seeded = try await health.seedHistory(now: now)
        let harness = CollectionHarness(store: health.store)

        do {
            // First sync: no anchors.
            let firstStarted = Date()
            let first = await harness.coordinator.querySensors(Set(CollectionHealthStore.sensors))
            let firstSeconds = Date().timeIntervalSince(firstStarted)
            let firstLogs = await harness.ownLogs()

            for result in first {
                #expect(result.status == .success, "\(result.sensor.rawValue): \(result.status.rawValue) \(result.errorDescription ?? result.message ?? "")")
                #expect(result.anchorUpdated, "\(result.sensor.rawValue): the anchor was not saved")
            }

            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: now)!
            for sensor in CollectionHealthStore.quantitySensors {
                let logs = firstLogs.filter { $0.dataType == sensor.rawValue }
                let expectedStarts = seeded.inWindowStarts.map(\.timeIntervalSinceReferenceDate).sorted()
                let collectedStarts = logs.map(\.startDate.timeIntervalSinceReferenceDate).sorted()
                #expect(collectedStarts == expectedStarts, "\(sensor.rawValue): collected \(logs.count) logs, expected \(expectedStarts.count) (one per in-window sample)")
                #expect(logs.allSatisfy { $0.value == CollectionHealthStore.value(for: sensor) }, "\(sensor.rawValue): a collected value differs from the seeded value")
                #expect(logs.allSatisfy { $0.endDate >= cutoff }, "\(sensor.rawValue): a sample older than 30 days was collected")
            }

            let sessions = firstLogs.filter { $0.dataType == "sleep_session" }
            let stages = firstLogs.filter { $0.dataType.hasPrefix("sleep_stage_") }
            #expect(sessions.count == 1, "Expected one sleep_session for the seeded night, got \(sessions.count)")
            #expect(stages.count == seeded.sleepStages, "Expected \(seeded.sleepStages) sleep stage logs, got \(stages.count)")
            if let session = sessions.first {
                #expect(stages.allSatisfy { $0.parentId == session.id }, "A sleep stage does not point at its session")
            }
            #expect(Set(firstLogs.map(\.id)).count == firstLogs.count, "The first sync queued the same data log twice")

            // A second sync with nothing new queues nothing. It may still fetch the
            // out-of-window samples once (they were saved after the in-window ones, so they
            // sit past the first sync's anchor); the SDK drops them and advances.
            await harness.resetLogs()
            let second = await harness.coordinator.querySensors(Set(CollectionHealthStore.sensors))
            let secondLogs = await harness.ownLogs()
            #expect(secondLogs.isEmpty, "A re-sync with no new samples queued \(secondLogs.count) logs again")
            #expect(second.allSatisfy { $0.status != .failed }, "Re-sync statuses: \(second.map { "\($0.sensor.rawValue)=\($0.status.rawValue)" })")

            // New samples: only they are collected.
            let newSteps = [now.addingTimeInterval(-600), now.addingTimeInterval(-300)]
            let newHeartRate = [now.addingTimeInterval(-120)]
            try await health.save(newSteps.map { health.quantitySample(.steps, start: $0) }
                + newHeartRate.map { health.quantitySample(.heart_rate, start: $0) })
            await harness.resetLogs()
            _ = await harness.coordinator.querySensors(Set(CollectionHealthStore.sensors))
            let thirdLogs = await harness.ownLogs()
            #expect(thirdLogs.filter { $0.dataType == SahhaSensor.steps.rawValue }.count == newSteps.count)
            #expect(thirdLogs.filter { $0.dataType == SahhaSensor.heart_rate.rawValue }.count == newHeartRate.count)
            #expect(thirdLogs.count == newSteps.count + newHeartRate.count, "The incremental sync queued \(thirdLogs.count) logs, expected only the \(newSteps.count + newHeartRate.count) new samples")

            #expect(harness.logger.messages.isEmpty, "The SDK posted errors: \(harness.logger.messages)")

            DeviceTestReport.record("data-collection-first-sync", [
                "sensors": CollectionHealthStore.sensors.map(\.rawValue),
                "firstSyncSeconds": DeviceTestReport.seconds(firstSeconds),
                "firstSyncLogs": firstLogs.count,
                "inWindowSamplesPerSensor": seeded.inWindowStarts.count,
                "outOfWindowSamplesPerSensor": seeded.outOfWindowCount,
                "statuses": Dictionary(uniqueKeysWithValues: first.map { ($0.sensor.rawValue, $0.status.rawValue) }),
            ])
        } catch {
            await harness.coordinator.dispose()
            try await health.deleteTagged()
            throw error
        }
        await harness.coordinator.dispose()
        try await health.deleteTagged()
    }

    // MARK: - Observer delivery

    @Test("Samples saved while collection is running reach the upload queue without a manual sync", .timeLimit(.minutes(3)))
    func observerDeliversNewSamples() async throws {
        try await health.authorize()
        try await health.deleteTagged()
        let harness = CollectionHarness(store: health.store)
        let observed: Set<SahhaSensor> = [.steps, .heart_rate]

        // Starts the observers and enables background delivery, as `enableSensors` does.
        // The host app carries the background-delivery entitlement, so both must succeed.
        var backgroundDeliveryError: String?
        do {
            try await harness.coordinator.startDataLogCollection(for: observed)
        } catch {
            backgroundDeliveryError = "\(error)"
        }
        #expect(backgroundDeliveryError == nil, "Enabling background delivery failed: \(backgroundDeliveryError ?? "")")

        do {
            // Let the observers' initial runs finish first.
            try await Task.sleep(nanoseconds: 3_000_000_000)
            await harness.resetLogs()

            let now = Date()
            let steps = (1...3).map { now.addingTimeInterval(TimeInterval(-60 * $0)) }
            let heartRate = (1...2).map { now.addingTimeInterval(TimeInterval(-90 * $0)) }
            let saved = Date()
            try await health.save(steps.map { health.quantitySample(.steps, start: $0) }
                + heartRate.map { health.quantitySample(.heart_rate, start: $0) })

            let arrived = await harness.waitForLogs(timeout: 30) { logs in
                logs.filter { $0.dataType == SahhaSensor.steps.rawValue }.count >= steps.count
                    && logs.filter { $0.dataType == SahhaSensor.heart_rate.rawValue }.count >= heartRate.count
            }
            let latency = Date().timeIntervalSince(saved)
            let logs = await harness.ownLogs()
            #expect(arrived, "Observer delivery: after 30s only \(logs.count) of \(steps.count + heartRate.count) new samples reached the queue")
            #expect(logs.count == steps.count + heartRate.count, "Observer delivery queued \(logs.count) logs for \(steps.count + heartRate.count) new samples")

            DeviceTestReport.record("data-collection-observer", [
                "arrived": arrived,
                "latencySeconds": DeviceTestReport.seconds(latency),
                "backgroundDeliveryError": backgroundDeliveryError ?? NSNull(),
            ])
        } catch {
            await harness.stopObserving(observed)
            try await health.deleteTagged()
            throw error
        }
        await harness.stopObserving(observed)
        try await health.deleteTagged()
    }

    /// Samples saved one at a time in quick succession, the way a watch syncs. Each save
    /// fires the observer; a trigger that lands while a run is finishing must not be lost.
    @Test("A burst of separate saves is collected in full by observer delivery", .timeLimit(.minutes(3)))
    func observerBurstIsNotLost() async throws {
        try await health.authorize()
        try await health.deleteTagged()
        let harness = CollectionHarness(store: health.store)

        try await harness.coordinator.startDataLogCollection(for: [.steps])

        do {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            await harness.resetLogs()

            let now = Date()
            let burst = 20
            for index in 0..<burst {
                try await health.save([health.quantitySample(.steps, start: now.addingTimeInterval(TimeInterval(-10 * (index + 1))))])
                try await Task.sleep(nanoseconds: 75_000_000)
            }

            let arrived = await harness.waitForLogs(timeout: 30) { logs in
                logs.filter { $0.dataType == SahhaSensor.steps.rawValue }.count >= burst
            }
            let logs = await harness.ownLogs()
            #expect(arrived, "Burst: after 30s only \(logs.count) of \(burst) separately saved samples reached the queue")
            #expect(logs.count == burst, "Burst queued \(logs.count) logs for \(burst) samples")

            DeviceTestReport.record("data-collection-burst", [
                "saves": burst,
                "collected": logs.count,
            ])
        } catch {
            await harness.stopObserving([.steps])
            try await health.deleteTagged()
            throw error
        }
        await harness.stopObserving([.steps])
        try await health.deleteTagged()
    }

    // MARK: - Deletions

    /// HealthKit returns deleted objects in anchored-query pages and counts them toward the
    /// page limit, so a run of deletions longer than a page arrives as pages with no
    /// samples. A sync that stops at the first sample-free page, without saving the anchor
    /// HealthKit advanced, re-reads the same deletions on every trigger and never reaches
    /// the samples behind them. Deletions come from a sync app rewriting history, a removed
    /// app's data, or a user clearing a source.
    @Test("Deletions longer than a page don't stop collection of the samples after them", .timeLimit(.minutes(3)))
    func deletionsDoNotStallCollection() async throws {
        try await health.authorize()
        try await health.deleteTagged()
        let harness = CollectionHarness(store: health.store)

        do {
            let now = Date()
            let history = (0..<600).map { health.quantitySample(.steps, start: now.addingTimeInterval(-86_400 - Double($0) * 60)) }
            try await health.save(history)
            _ = await harness.coordinator.querySensors([.steps])
            let collectedHistory = await harness.ownLogs().count
            #expect(collectedHistory == history.count, "The first sync collected \(collectedHistory) of \(history.count) samples")

            // Every one of them is deleted, then new samples arrive.
            try await health.deleteTagged()
            await harness.resetLogs()
            let fresh = [now.addingTimeInterval(-120), now.addingTimeInterval(-60)]
            try await health.save(fresh.map { health.quantitySample(.steps, start: $0) })

            let result = await harness.coordinator.querySensors([.steps])
            let logs = await harness.ownLogs()
            #expect(logs.count == fresh.count, "After \(history.count) deletions the next sync collected \(logs.count) of \(fresh.count) new samples (status \(result.first?.status.rawValue ?? "none"), fetched \(result.first?.samplesFetched ?? 0))")

            DeviceTestReport.record("data-collection-deletions", [
                "deleted": history.count,
                "newSamples": fresh.count,
                "collected": logs.count,
                "status": result.first?.status.rawValue ?? NSNull(),
            ])
        } catch {
            await harness.coordinator.dispose()
            try await health.deleteTagged()
            throw error
        }
        await harness.coordinator.dispose()
        try await health.deleteTagged()
    }

    // MARK: - Every sensor at once

    @Test("Querying every HealthKit sensor at once, twice concurrently, finishes without a failure", .timeLimit(.minutes(5)))
    func everySensorAtOnceFinishes() async throws {
        try await health.authorize()
        let sensors = Set(SahhaSensor.allCases.filter { $0.hkSampleType != nil })
        // As a host app enabling every sensor would: one SDK permission request for all of
        // them (the sheet appears on the first run only). A type never asked for fails its
        // query with "Authorization not determined", which production never queries.
        try await HealthKitPermissionsService(healthStore: health.store).requestPermissions(for: sensors)
        let harness = CollectionHarness(store: health.store)

        let started = Date()
        async let firstPass = harness.coordinator.querySensors(sensors)
        async let overlappingPass = harness.coordinator.querySensors(sensors)
        let (first, second) = await (firstPass, overlappingPass)
        let seconds = Date().timeIntervalSince(started)

        #expect(first.count == sensors.count)
        #expect(second.count == sensors.count)
        let failed = (first + second).filter { $0.status == .failed }
        #expect(failed.isEmpty, "Failed: \(failed.map { "\($0.sensor.rawValue): \($0.errorDescription ?? $0.message ?? "")" })")
        #expect(harness.logger.messages.isEmpty, "The SDK posted errors: \(harness.logger.messages)")

        DeviceTestReport.record("data-collection-all-sensors", [
            "sensors": sensors.count,
            "seconds": DeviceTestReport.seconds(seconds),
        ])
        await harness.coordinator.dispose()
    }
}

// MARK: - Live upload

/// The rest of the production chain, against a live API: what the data-log coordinator
/// collects from real HealthKit goes through the SDK's DataLogPipeline, UnifiedUploader
/// (chunking, priorities, retry, sent-item store) and DataLogService, authorised by the
/// SDK's own AuthManager and interceptor. A log counts as uploaded only once the
/// uploader marks it sent, which it does after the API answers 2xx.
///
/// Skipped without app credentials. Talks to SAHHA_ENVIRONMENT (sandbox by default,
/// development allowed, production refused) and uploads only this app's tagged test
/// samples, to the profile with external id `sahha-ios-device-tests`, which the
/// token-refresh tests also use.
@Suite(
    "Collected data uploaded to the live API",
    .serialized,
    .enabled(if: DeviceTestEnv.hasAppCredentials, "Pass TEST_RUNNER_SAHHA_APP_ID and TEST_RUNNER_SAHHA_APP_SECRET to run")
)
struct LiveUploadDeviceTests {
    private let health = CollectionHealthStore.shared
    private let environment = DeviceTestEnv.apiEnvironment

    @Test("A first sync's data logs from real HealthKit are accepted by the API", .timeLimit(.minutes(5)))
    func firstSyncIsUploaded() async throws {
        try await health.authorize()
        try await health.deleteTagged()
        let upload = try await LiveUploadChain(environment: environment)
        let harness = CollectionHarness(store: health.store, upload: upload.pipeline)

        do {
            _ = try await health.seedHistory(now: Date())
            let started = Date()
            _ = await harness.coordinator.querySensors(Set(CollectionHealthStore.sensors))
            let logs = await harness.ownLogs()
            #expect(!logs.isEmpty, "Nothing was collected to upload")

            let sent = await upload.waitUntilSent(logs, timeout: 90)
            let seconds = Date().timeIntervalSince(started)
            #expect(sent == logs.count, "\(sent) of \(logs.count) data logs were accepted by \(environment.rawValue) within 90s")
            #expect(upload.logger.messages.isEmpty, "The uploader posted errors: \(upload.logger.messages)")
            let queued = await upload.uploader.getDLQStatistics()
            #expect(queued.totalItems == 0, "\(queued.totalItems) items were left in the retry queue")

            DeviceTestReport.record("live-upload-first-sync", [
                "environment": environment.rawValue,
                "logs": logs.count,
                "sent": sent,
                "secondsToSent": DeviceTestReport.seconds(seconds),
            ])
        } catch {
            await harness.coordinator.dispose()
            await upload.tearDown()
            try await health.deleteTagged()
            throw error
        }
        await harness.coordinator.dispose()
        await upload.tearDown()
        try await health.deleteTagged()
    }

    @Test("Samples saved while collection runs are uploaded without a manual sync", .timeLimit(.minutes(5)))
    func observedSamplesAreUploaded() async throws {
        try await health.authorize()
        try await health.deleteTagged()
        let upload = try await LiveUploadChain(environment: environment)
        let harness = CollectionHarness(store: health.store, upload: upload.pipeline)
        let observed: Set<SahhaSensor> = [.steps, .heart_rate]

        do {
            // Observers plus background delivery, as `enableSensors` arms them.
            try await harness.coordinator.startDataLogCollection(for: observed)
            try await Task.sleep(nanoseconds: 3_000_000_000)
            await harness.resetLogs()

            let now = Date()
            let saved = Date()
            try await health.save([
                health.quantitySample(.steps, start: now.addingTimeInterval(-120)),
                health.quantitySample(.steps, start: now.addingTimeInterval(-60)),
                health.quantitySample(.heart_rate, start: now.addingTimeInterval(-30)),
            ])

            let collected = await harness.waitForLogs(timeout: 30) { $0.count >= 3 }
            let logs = await harness.ownLogs()
            #expect(collected, "Only \(logs.count) of 3 new samples were collected")
            let sent = await upload.waitUntilSent(logs, timeout: 90)
            #expect(sent == 3, "\(sent) of 3 observed samples were accepted by \(environment.rawValue) within 90s")
            #expect(upload.logger.messages.isEmpty, "The uploader posted errors: \(upload.logger.messages)")

            DeviceTestReport.record("live-upload-observer", [
                "environment": environment.rawValue,
                "sent": sent,
                "secondsFromSaveToSent": DeviceTestReport.seconds(Date().timeIntervalSince(saved)),
            ])
        } catch {
            await harness.stopObserving(observed)
            await upload.tearDown()
            try await health.deleteTagged()
            throw error
        }
        await harness.stopObserving(observed)
        await upload.tearDown()
        try await health.deleteTagged()
    }
}

/// The SDK's data-log upload chain, built the way `DataLogDI` and `AuthDI` build it, with
/// its retry queue and sent-item store kept apart from any real SDK state on the device.
private struct LiveUploadChain {
    let pipeline: DataLogPipeline
    let uploader: UnifiedUploader<DataLog, DataLogRequest>
    let logger: RecordingErrorLogger
    private let sentStore: SentItemStore
    private let sentKey: String
    private let queueDirectory: URL

    init(environment: SahhaEnvironment) async throws {
        let auth = AuthService(apiClient: APIClient(baseURL: environment.baseURL))
        let tokens = try await auth.authenticate(
            appId: try #require(DeviceTestEnv.appId),
            appSecret: try #require(DeviceTestEnv.appSecret),
            externalId: "sahha-ios-device-tests"
        )
        let manager = AuthManager(authService: auth, tokenStore: InMemoryTokenStore(tokens), logger: SilentErrorLogger())
        let interceptors = APIInterceptorStore()
        await interceptors.addInterceptor(AuthorizationInterceptor(authManager: manager))
        let service = DataLogService(apiClient: APIClient(baseURL: environment.baseURL, interceptorStore: interceptors))

        let logger = RecordingErrorLogger()
        self.logger = logger
        // The SDK's own device id (the vendor id, a UUID: the API rejects anything that
        // isn't a GUID), persisted under a key of this suite's so no SDK state is touched.
        let deviceId = await DeviceIdProvider(key: "sahha-device-test-device-id", storage: UserDefaultsStorage()).deviceId()
        let mapper = DataLogRequestMapper(deviceId: deviceId, logger: logger)
        let priorities = DefaultUploadPriorityAssigner()
        queueDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sahha-device-test-upload-\(UUID().uuidString)")
        sentKey = "sahha-device-test-sent-\(UUID().uuidString)"
        sentStore = SentItemStore(storage: UserDefaultsStorage(), storageKey: sentKey, logLabel: "DeviceTestSentLogs")
        uploader = UnifiedUploader<DataLog, DataLogRequest>(
            uploadService: { requests in try await service.postDataLogs(requests) },
            logger: logger,
            circuitBreaker: CircuitBreaker(),
            networkMonitor: NetworkMonitor(),
            persistentQueue: UnifiedDeadLetterQueue<DataLogRequest>(baseDirectory: queueDirectory, logLabel: "DeviceTest Persistent Queue"),
            streamingProcessor: StreamingChunkProcessor<DataLog, DataLogRequest>(
                mapItem: { mapper.map($0) },
                assignPriority: { priorities.assignPriority(to: $0) }
            ),
            sentStore: sentStore,
            logLabel: "DeviceTestUploader"
        )
        pipeline = DataLogPipeline(uploader: uploader)
    }

    /// How many of `logs` the uploader has marked sent, waiting up to `timeout` for all.
    func waitUntilSent(_ logs: [DataLog], timeout: TimeInterval) async -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var sent = 0
        repeat {
            sent = 0
            for log in logs where await sentStore.isSent(log.id) {
                sent += 1
            }
            if sent == logs.count { return sent }
            try? await Task.sleep(nanoseconds: 500_000_000)
        } while Date() < deadline
        return sent
    }

    func tearDown() async {
        await pipeline.dispose()
        await uploader.dispose()
        UserDefaults.standard.removeObject(forKey: sentKey)
        try? FileManager.default.removeItem(at: queueDirectory)
    }
}

// MARK: - Harness

/// A data-log coordinator built the way `HealthKitDI` builds it, around the real Health
/// store, with a recording pipeline and fresh anchors.
private struct CollectionHarness {
    let pipeline: RecordingPipeline
    let logger = RecordingErrorLogger()
    let coordinator: HealthKitDataLogCoordinator

    /// - Parameter upload: where to pass on the logs from this app's own samples, for
    ///   the live-upload tests. Other apps' data on the device is never passed on.
    init(store: HKHealthStore, upload: DataLogPipelineProtocol? = nil) {
        let pipeline = RecordingPipeline(upload: upload)
        self.pipeline = pipeline
        coordinator = HealthKitDataLogCoordinator(
            observerService: HealthKitObserverService(healthStore: store, observerStore: HealthKitObserverStore(), logger: logger),
            anchorQueryService: HealthKitAnchorQueryService(healthStore: store),
            anchorStore: MemoryAnchorStore(),
            normaliser: HKSampleToDataLogNormaliserRegistry(),
            profileIdProvider: FixedProfileId(),
            dataLogPipeline: pipeline,
            logger: logger
        )
    }

    /// Logs from samples this app wrote. Other apps' data on the device is ignored.
    func ownLogs() async -> [DataLog] {
        let source = HKSource.default().bundleIdentifier
        return await pipeline.logs.filter { $0.source == source }
    }

    func resetLogs() async {
        await pipeline.reset()
    }

    /// Stops the observers and disables background delivery, as `deauthenticate` does,
    /// so iOS stops waking this app for the types after the test. Then disposes.
    func stopObserving(_ sensors: Set<SahhaSensor>) async {
        do {
            try await coordinator.stopDataLogCollection(for: sensors)
        } catch {
            Issue.record("Stopping collection failed: \(error)")
        }
        await coordinator.dispose()
    }

    func waitForLogs(timeout: TimeInterval, until done: ([DataLog]) -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if done(await ownLogs()) { return true }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return done(await ownLogs())
    }
}

private actor RecordingPipeline: DataLogPipelineProtocol {
    private let upload: DataLogPipelineProtocol?
    private(set) var logs: [DataLog] = []

    init(upload: DataLogPipelineProtocol?) {
        self.upload = upload
    }

    func ingest(_ log: DataLog) async { await ingest([log]) }

    func ingest(_ logs: [DataLog]) async {
        self.logs.append(contentsOf: logs)
        let source = HKSource.default().bundleIdentifier
        let own = logs.filter { $0.source == source }
        if let upload, !own.isEmpty {
            await upload.ingest(own)
        }
    }

    func reset() { logs.removeAll() }
}

private actor MemoryAnchorStore: HealthKitAnchorStoreProtocol {
    private var anchors: [String: HKQueryAnchor] = [:]
    func saveAnchor(_ anchor: HKQueryAnchor, forKey key: String) throws { anchors[key] = anchor }
    func loadAnchor(forKey key: String) throws -> HKQueryAnchor? { anchors[key] }
}

private struct FixedProfileId: ProfileIdProviderProtocol {
    func profileId() -> String? { "device-test-profile" }
}

private final class RecordingErrorLogger: ErrorLoggerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    func postError(_ error: Error, file: StaticString, function: StaticString, line: UInt) {
        lock.lock()
        recorded.append("\(file):\(line) \(error)")
        lock.unlock()
    }

    var messages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }
}

// MARK: - HealthKit seeding

/// Writes and deletes this suite's tagged samples.
private final class CollectionHealthStore: @unchecked Sendable {
    static let shared = CollectionHealthStore()
    static let tag = "SahhaDeviceTestCollection"

    static let quantitySensors: [SahhaSensor] = [.steps, .heart_rate, .active_energy_burned, .resting_heart_rate, .heart_rate_variability_sdnn]
    static let sensors: [SahhaSensor] = quantitySensors + [.sleep]

    static func value(for sensor: SahhaSensor) -> Double {
        switch sensor {
        case .steps: return 100
        case .heart_rate: return 72
        case .active_energy_burned: return 15
        case .resting_heart_rate: return 58
        case .heart_rate_variability_sdnn: return 45
        default: return 1
        }
    }

    let store = HKHealthStore()

    private var seedTypes: Set<HKSampleType> {
        Set(Self.sensors.compactMap(\.hkSampleType))
    }

    /// Write access for the seeded types, then the SDK's own permission request for the
    /// collected sensors (read). The sheets appear on the first run only.
    ///
    /// The SDK's request goes second because it waits for a previous Health sheet to
    /// leave the screen first (a request made while one is dismissing never presents);
    /// HealthKit's own request does not wait.
    func authorize() async throws {
        try await store.requestAuthorization(toShare: seedTypes, read: seedTypes)
        try await HealthKitPermissionsService(healthStore: store).requestPermissions(for: Set(Self.sensors))
        for type in seedTypes where store.authorizationStatus(for: type) != .sharingAuthorized {
            throw CollectionTestError.writeNotAllowed(type.identifier)
        }
    }

    struct Seeded {
        var inWindowStarts: [Date]
        var outOfWindowCount: Int
        var sleepStages: Int
    }

    /// For each quantity sensor, one sample at each in-window age (from just inside the
    /// 30-day window to an hour ago) and one older than the window; plus one night of
    /// sleep stages two days ago.
    func seedHistory(now: Date) async throws -> Seeded {
        let day: TimeInterval = 86_400
        let inWindow = [29.5 * day, 15 * day, day, 3_600].map { now.addingTimeInterval(-$0) }
        let outOfWindow = [31 * day].map { now.addingTimeInterval(-$0) }

        var samples: [HKObject] = []
        for sensor in Self.quantitySensors {
            samples += (inWindow + outOfWindow).map { quantitySample(sensor, start: $0) }
        }

        let nightStart = Calendar.current.startOfDay(for: now.addingTimeInterval(-2 * day)).addingTimeInterval(-3_600)
        let stages: [(HKCategoryValueSleepAnalysis, TimeInterval)] = [(.asleepCore, 7_200), (.asleepDeep, 3_600), (.asleepREM, 3_600)]
        var stageStart = nightStart
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        for (stage, length) in stages {
            samples.append(HKCategorySample(type: sleepType, value: stage.rawValue, start: stageStart, end: stageStart.addingTimeInterval(length), metadata: [Self.tag: true]))
            stageStart = stageStart.addingTimeInterval(length)
        }

        try await save(samples)
        return Seeded(inWindowStarts: inWindow, outOfWindowCount: outOfWindow.count, sleepStages: stages.count)
    }

    func quantitySample(_ sensor: SahhaSensor, start: Date) -> HKQuantitySample {
        HKQuantitySample(
            type: sensor.hkSampleType as! HKQuantityType,
            quantity: HKQuantity(unit: sensor.hkUnit!, doubleValue: Self.value(for: sensor)),
            start: start,
            end: start.addingTimeInterval(60),
            metadata: [Self.tag: true]
        )
    }

    func save(_ samples: [HKObject]) async throws {
        try await store.save(samples)
    }

    /// Deletes every sample this suite wrote: this app's source and the suite's tag only.
    @discardableResult
    func deleteTagged() async throws -> Int {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(from: HKSource.default()),
            HKQuery.predicateForObjects(withMetadataKey: Self.tag),
        ])
        var deleted = 0
        for type in seedTypes {
            deleted += try await withCheckedThrowingContinuation { continuation in
                store.deleteObjects(of: type, predicate: predicate) { _, count, error in
                    if let error = error as? HKError, error.code == .errorNoData {
                        continuation.resume(returning: 0)
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: count)
                    }
                }
            }
        }
        return deleted
    }
}

private enum CollectionTestError: Error, CustomStringConvertible {
    case writeNotAllowed(String)

    var description: String {
        switch self {
        case .writeNotAllowed(let type):
            return "Writing \(type) is off for Sahha Device Tests. Turn it on in Settings > Health > Data Access & Devices, then run again."
        }
    }
}
