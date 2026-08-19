import Testing
import Foundation
import HealthKit
@testable import Sahha

// Coverage for idempotent, total deauthentication (PRD #76 D13).
//
// Deauthentication is a hybrid teardown: the DI container reset disposes every
// *resolved* service first (observers stopped, background deliveries disabled,
// write-back latches set), then the static `DeauthenticationPurge` wipes an
// explicitly enumerated inventory of SDK-owned state — with no container
// required, so logout succeeds before configure has ever run. Three layers:
// - the purge routine is pure and tested against injected doubles;
// - the storage-keys completeness suite proves every key constant carries an
//   explicit purge-or-keep decision, so a future key fails the suite until one
//   is made;
// - actor-level tests drive the non-shared `SahhaActor` seam with a purge
//   bound to the same doubles, so no test touches real storage. Nothing here
//   asserts on the process-global `Sahha.authSnapshot` (DeferredBringUpTests
//   owns that); the purge's snapshot effect is asserted on injected instances.

// MARK: - Seeding helpers

private func seedPurgedUserDefaults(_ storage: InMemoryStorage) throws {
    storage.set(Data([1]), forKey: StorageKeys.UserDefaults.deviceInfo.rawValue)
    storage.set(try JSONEncoder().encode(["sleep"]), forKey: StorageKeys.UserDefaults.sensors.rawValue)
    storage.set(Data([2]), forKey: StorageKeys.UserDefaults.sentLogIds.rawValue)
    storage.set(Data([3]), forKey: StorageKeys.UserDefaults.sentTagIds.rawValue)
    storage.set(Data([4]), forKey: StorageKeys.UserDefaults.diagnosticReport.rawValue)
    storage.set(true, forKey: StorageKeys.UserDefaults.dlqMigration.rawValue)
    // One member key per family, canonical and legacy alias forms alike.
    storage.set(Data([5]), forKey: "hkAnchor.sleep")
    storage.set(Data([6]), forKey: "sahha_hkAnchor.energy_consumed")
    storage.set(Date(), forKey: "hkAnchorDate.activity_summary")
    storage.set(Date(), forKey: "date_hkAnchorDate.activity_summary")
}

private func seedKeptUserDefaults(_ storage: InMemoryStorage) {
    storage.set("stable-device-id", forKey: StorageKeys.UserDefaults.deviceId.rawValue)
}

private func seedKeychain(_ keychain: MockKeychainStorage) throws {
    try keychain.set(Data([7]), forKey: StorageKeys.Keychain.token.rawValue)
    try keychain.set(Data([8]), forKey: StorageKeys.Keychain.demographic.rawValue)
}

private func makeDLQDirs() throws -> [URL] {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent("deauth-\(UUID().uuidString)")
    let dirs = [
        base.appendingPathComponent("data-logs", isDirectory: true),
        base.appendingPathComponent("tags", isDirectory: true),
    ]
    for dir in dirs {
        let queue = dir.appendingPathComponent("PersistentQueue", isDirectory: true)
        try FileManager.default.createDirectory(at: queue, withIntermediateDirectories: true)
        try Data([9]).write(to: queue.appendingPathComponent("batch_test.json"))
    }
    return dirs
}

/// The profile-state assertions shared by purge-level and actor-level tests.
/// `dlqMigration` is deliberately not asserted absent: it is a session flag the
/// reconfigure inside actor-level deauthentication legitimately rewrites.
private func expectProfileStatePurged(
    storage: InMemoryStorage,
    keychain: MockKeychainStorage,
    snapshot: AuthSnapshot,
    dlqDirs: [URL]
) {
    #expect(storage.get(forKey: StorageKeys.UserDefaults.deviceInfo.rawValue) == nil)
    #expect(storage.get(forKey: StorageKeys.UserDefaults.sensors.rawValue) == nil)
    #expect(storage.get(forKey: StorageKeys.UserDefaults.sentLogIds.rawValue) == nil)
    #expect(storage.get(forKey: StorageKeys.UserDefaults.sentTagIds.rawValue) == nil)
    #expect(storage.get(forKey: StorageKeys.UserDefaults.diagnosticReport.rawValue) == nil)
    let prefixes = StorageKeys.UserDefaultsPrefix.allCases.map(\.rawValue)
    let familySurvivors = storage.allKeys { key in prefixes.contains { key.hasPrefix($0) } }
    #expect(familySurvivors.isEmpty)
    #expect(keychain.storedKeys.isEmpty)
    #expect(snapshot.profileToken == nil)
    #expect(snapshot.profileId == nil)
    for dir in dlqDirs {
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }
    // The keep-list survives.
    #expect(storage.string(forKey: StorageKeys.UserDefaults.deviceId.rawValue) == "stable-device-id")
}

// MARK: - Purge routine (container-free)

@Suite("Deauthentication purge inventory (D13)")
struct DeauthenticationPurgeTests {

    @Test("The purge clears every enumerated item with no DI container present, and deviceId survives byte-identical")
    func purgeClearsInventoryWithoutContainer() async throws {
        let storage = InMemoryStorage()
        let keychain = MockKeychainStorage()
        let snapshot = AuthSnapshot()
        let dlqDirs = try makeDLQDirs()
        defer { dlqDirs.forEach { try? FileManager.default.removeItem(at: $0.deletingLastPathComponent()) } }
        try seedPurgedUserDefaults(storage)
        seedKeptUserDefaults(storage)
        try seedKeychain(keychain)
        snapshot.profileToken = "departing-profile-token"
        snapshot.profileId = "departing-profile-id"

        // No DIContainer exists anywhere in this test: the purge is total.
        DeauthenticationPurge.run(
            userDefaults: storage,
            keychain: keychain,
            directories: dlqDirs,
            snapshot: snapshot
        )

        expectProfileStatePurged(storage: storage, keychain: keychain, snapshot: snapshot, dlqDirs: dlqDirs)
        #expect(storage.get(forKey: StorageKeys.UserDefaults.dlqMigration.rawValue) == nil)
        // Nothing but the keep-list remains.
        #expect(storage.allKeys() == [StorageKeys.UserDefaults.deviceId.rawValue])
    }

    @Test("Legacy-prefixed alias keys are purged alongside their canonical families")
    func legacyAliasFamiliesPurged() async throws {
        let storage = InMemoryStorage()
        storage.set(Data([1]), forKey: "hkAnchor.steps")
        storage.set(Data([2]), forKey: "sahha_hkAnchor.steps")
        storage.set(Data([3]), forKey: "sahha_hkAnchor.dietary_carbohydrates")
        storage.set(Date(), forKey: "hkAnchorDate.activity_summary")
        storage.set(Date(), forKey: "date_hkAnchorDate.activity_summary")

        DeauthenticationPurge.run(
            userDefaults: storage,
            keychain: MockKeychainStorage(),
            directories: [],
            snapshot: AuthSnapshot()
        )

        #expect(storage.allKeys().isEmpty)
    }

    @Test("A second purge is a no-op that leaves storage byte-identical")
    func purgeIsIdempotent() async throws {
        let storage = InMemoryStorage()
        let keychain = MockKeychainStorage()
        let snapshot = AuthSnapshot()
        try seedPurgedUserDefaults(storage)
        seedKeptUserDefaults(storage)
        try seedKeychain(keychain)

        DeauthenticationPurge.run(userDefaults: storage, keychain: keychain, directories: [], snapshot: snapshot)
        let keysAfterFirst = storage.allKeys().sorted()
        let deviceIdAfterFirst = storage.string(forKey: StorageKeys.UserDefaults.deviceId.rawValue)

        DeauthenticationPurge.run(userDefaults: storage, keychain: keychain, directories: [], snapshot: snapshot)

        #expect(storage.allKeys().sorted() == keysAfterFirst)
        #expect(storage.string(forKey: StorageKeys.UserDefaults.deviceId.rawValue) == deviceIdAfterFirst)
        #expect(keychain.storedKeys.isEmpty)
    }

    @Test("A throwing keychain cannot shield the rest of the inventory")
    func throwingKeychainDoesNotAbortPurge() async throws {
        let storage = InMemoryStorage()
        let keychain = MockKeychainStorage()
        let snapshot = AuthSnapshot()
        try seedPurgedUserDefaults(storage)
        snapshot.profileToken = "departing-profile-token"
        keychain.errorToThrow = SahhaError(message: "keychain unavailable")

        DeauthenticationPurge.run(userDefaults: storage, keychain: keychain, directories: [], snapshot: snapshot)

        #expect(storage.allKeys().isEmpty)
        #expect(snapshot.profileToken == nil)
    }
}

// MARK: - Storage-keys completeness

@Suite("Storage keys completeness (D13)")
struct StorageKeysCompletenessTests {

    @Test("Every UserDefaults key appears in exactly one of the purge/keep lists")
    func userDefaultsKeysAreFullyDecided() {
        let purged = Set(DeauthenticationPurge.purgedUserDefaultsKeys)
        let kept = Set(DeauthenticationPurge.keptUserDefaultsKeys)
        #expect(purged.intersection(kept).isEmpty)
        #expect(purged.union(kept) == Set(StorageKeys.UserDefaults.allCases))
    }

    @Test("Every UserDefaults key family is purged")
    func prefixFamiliesAreFullyDecided() {
        #expect(Set(DeauthenticationPurge.purgedUserDefaultsPrefixes) == Set(StorageKeys.UserDefaultsPrefix.allCases))
    }

    @Test("Every keychain key appears in exactly one of the purge/keep lists")
    func keychainKeysAreFullyDecided() {
        let purged = Set(DeauthenticationPurge.purgedKeychainKeys)
        let kept = Set(DeauthenticationPurge.keptKeychainKeys)
        #expect(purged.intersection(kept).isEmpty)
        #expect(purged.union(kept) == Set(StorageKeys.Keychain.allCases))
    }

    @Test("The on-disk key strings are pinned")
    func rawValuesArePinned() {
        // These raw values ARE the persisted format: renaming one silently
        // orphans every installed device's stored state (the 1.3.9 incident
        // class this PRD remediates).
        #expect(StorageKeys.UserDefaults.deviceId.rawValue == "deviceId")
        #expect(StorageKeys.UserDefaults.deviceInfo.rawValue == "deviceInfo")
        #expect(StorageKeys.UserDefaults.sensors.rawValue == "sensors")
        #expect(StorageKeys.UserDefaults.sentLogIds.rawValue == "sentLogIds")
        #expect(StorageKeys.UserDefaults.sentTagIds.rawValue == "sentTagIds")
        #expect(StorageKeys.UserDefaults.diagnosticReport.rawValue == "com.sahha.diagnostic_report")
        #expect(StorageKeys.UserDefaults.dlqMigration.rawValue == "dlq_migration_v1_complete")
        #expect(StorageKeys.UserDefaultsPrefix.hkAnchor.rawValue == "hkAnchor.")
        #expect(StorageKeys.UserDefaultsPrefix.hkAnchorDate.rawValue == "hkAnchorDate.")
        #expect(StorageKeys.Keychain.token.rawValue == "token")
        #expect(StorageKeys.Keychain.demographic.rawValue == "demographic")
        #expect(StorageKeys.Keychain.service == "ai.sahha.ios")
        // The legacy families compose from the canonical prefixes — the anchor
        // stores' fallback reads and the purge must agree on these forms.
        #expect(StorageKeys.UserDefaultsPrefix.legacyHkAnchor.rawValue
            == "sahha_" + StorageKeys.UserDefaultsPrefix.hkAnchor.rawValue)
        #expect(StorageKeys.UserDefaultsPrefix.legacyHkAnchorDate.rawValue
            == "date_" + StorageKeys.UserDefaultsPrefix.hkAnchorDate.rawValue)
    }
}

// MARK: - Actor-level doubles

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return _count
    }
    func increment() {
        lock.lock(); defer { lock.unlock() }
        _count += 1
    }
}

// `DeauthGate` and `GateTagPipeline` live in TestSupport/DeauthTestDoubles.swift: the
// pipeline protocol's `Tag` is ambiguous in files that import Testing.

/// Suspends `authenticate` until released, so deauthentication can be driven
/// deterministically mid-flight.
private actor GatedAuthService: AuthServiceProtocol {
    private(set) var entered = false
    private var continuation: CheckedContinuation<TokenResponse, Error>?
    private var pendingResult: Result<TokenResponse, Error>?

    func authenticate(appId: String, appSecret: String, externalId: String) async throws -> TokenResponse {
        entered = true
        if let pendingResult {
            return try pendingResult.get()
        }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func refreshToken(refreshToken: String) async throws -> TokenResponse {
        throw SahhaError(message: "refresh is not scripted in GatedAuthService")
    }

    func release(_ result: Result<TokenResponse, Error>) {
        if let continuation {
            continuation.resume(with: result)
            self.continuation = nil
        } else {
            pendingResult = result
        }
    }
}

private final class NullAPIClient: APIClientProtocol, @unchecked Sendable {
    func send(_ request: APIRequest) async throws {}
    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        throw SahhaError(message: "typed send is not scripted in NullAPIClient")
    }
}

private struct EmptySampleQueryService: HealthKitSampleQueryServiceProtocol {
    func runSampleQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKSample] {
        []
    }
}

/// HealthKit-manager double: resume reads the real sensor store and records
/// what it armed (leaving real observer-store bookkeeping behind so the
/// bring-up tail's health check finds a healthy store), and enableSensors
/// writes through the real store — so "resume is a no-op" and "a fresh enable
/// works" are both observable at the store boundary.
private final class StoreBackedManagerStub: HealthKitManagerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let sensorStore: SensorStoreProtocol
    private let observerStore: HealthKitObserverStoreProtocol
    private var _armedSets: [Set<SahhaSensor>] = []

    var armedSets: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _armedSets
    }

    init(sensorStore: SensorStoreProtocol, observerStore: HealthKitObserverStoreProtocol) {
        self.sensorStore = sensorStore
        self.observerStore = observerStore
    }

    func resumeSensors() async {
        guard let sensors = try? await sensorStore.getSensors() else { return }
        await arm(sensors)
    }

    func resumeSensors(for sensors: Set<SahhaSensor>) async {
        await arm(sensors)
    }

    private func recordArmed(_ sensors: Set<SahhaSensor>) {
        lock.lock(); defer { lock.unlock() }
        _armedSets.append(sensors)
    }

    private func arm(_ sensors: Set<SahhaSensor>) async {
        recordArmed(sensors)
        for sensor in sensors {
            guard let sampleType = sensor.hkSampleType else { continue }
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, _, _ in }
            await observerStore.replaceObserver(query, for: sensor, stoppingDisplaced: { _ in }, executing: { _ in })
            await observerStore.recordDeliveryEnabled(for: sensor)
        }
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        try await sensorStore.setSensors(sensors)
        await arm(sensors)
    }

    func querySensors() async -> PostSensorDataResult { PostSensorDataResult(sensorResults: []) }
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus { .pending }
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] { [] }
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] { [] }
    func getDemographic() async throws -> SahhaDemographic { SahhaDemographic() }
    func postInsights() async {}
}

/// Hands the registrar-built manager stub back to the test; replaced on every
/// container build, so it always refers to the current container's manager.
private final class ManagerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _manager: StoreBackedManagerStub?
    var manager: StoreBackedManagerStub? {
        lock.lock(); defer { lock.unlock() }
        return _manager
    }
    func set(_ manager: StoreBackedManagerStub) {
        lock.lock(); defer { lock.unlock() }
        _manager = manager
    }
}

/// Polls `condition` until it holds or `timeout` elapses; returns the final result.
private func waitUntil(timeout: Double = 5, _ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return await condition()
}

// MARK: - Actor-level fixture

/// A non-shared `SahhaActor` whose registrar swaps storage for doubles and
/// whose purge is bound to the same doubles, an isolated snapshot, and
/// temp-dir queues — deauthentication through this actor never touches real
/// storage.
private struct DeauthFixture {
    let storage: InMemoryStorage
    let keychain: MockKeychainStorage
    let snapshot: AuthSnapshot
    let dlqDirs: [URL]
    let purgeCount: Counter
    let registrarCount: Counter
    let box: ManagerBox
    let actor: SahhaActor

    init(
        authService: (any AuthServiceProtocol)? = nil,
        failConfigure: Bool = false,
        configureGate: DeauthGate? = nil,
        disposeGate: DeauthGate? = nil
    ) throws {
        let storage = InMemoryStorage()
        let keychain = MockKeychainStorage()
        let snapshot = AuthSnapshot()
        let dlqDirs = try makeDLQDirs()
        let purgeCount = Counter()
        let registrarCount = Counter()
        let box = ManagerBox()
        let service = authService ?? MockAuthService(refresh: [])

        self.storage = storage
        self.keychain = keychain
        self.snapshot = snapshot
        self.dlqDirs = dlqDirs
        self.purgeCount = purgeCount
        self.registrarCount = registrarCount
        self.box = box
        self.actor = SahhaActor(
            registrar: { container, settings in
                registrarCount.increment()
                await configureGate?.waitUntilOpen()
                // A registrar that registers nothing makes configure's own
                // resolutions throw — the "failing configure" fixture mode.
                if failConfigure { return }
                await SahhaActor.registerProductionDependencies(container: container, settings: settings)
                await container.register(UserDefaultsStorageProtocol.self) { _ in storage }
                await container.register(KeychainStorageProtocol.self) { _ in keychain }
                await container.register(ErrorLoggerProtocol.self) { _ in NoopErrorLogger() }
                await container.register(APIClientProtocol.self) { _ in NullAPIClient() }
                await container.register(AuthServiceProtocol.self) { _ in service }
                await container.register(HealthKitSampleQueryServiceProtocol.self) { _ in EmptySampleQueryService() }
                await container.register(HealthKitManagerProtocol.self) { container in
                    let manager = StoreBackedManagerStub(
                        sensorStore: try await container.resolve(SensorStoreProtocol.self),
                        observerStore: try await container.resolve(HealthKitObserverStoreProtocol.self)
                    )
                    box.set(manager)
                    return manager
                }
                if let disposeGate {
                    await container.register(TagPipelineProtocol.self) { _ in
                        GateTagPipeline(gate: disposeGate)
                    }
                }
            },
            lifecycleObserver: LifecycleObserverSpy(),
            retryMonitorFactory: { NetworkMonitor(isConnected: true) },
            purge: {
                purgeCount.increment()
                DeauthenticationPurge.run(
                    userDefaults: storage,
                    keychain: keychain,
                    directories: dlqDirs,
                    snapshot: snapshot
                )
            }
        )
    }

    func seedFullInventory() throws {
        try seedPurgedUserDefaults(storage)
        seedKeptUserDefaults(storage)
        try seedKeychain(keychain)
        snapshot.profileToken = "departing-profile-token"
        snapshot.profileId = "departing-profile-id"
    }

    func cleanUp() {
        dlqDirs.forEach { try? FileManager.default.removeItem(at: $0.deletingLastPathComponent()) }
    }
}

// MARK: - Actor-level suite

@Suite("Idempotent deauthentication (D13)")
struct IdempotentDeauthenticationTests {

    @Test("Deauth before configure ever runs succeeds, purges, and skips the reconfigure")
    func deauthBeforeConfigureSucceedsAndPurges() async throws {
        let fixture = try DeauthFixture()
        defer { fixture.cleanUp() }
        try fixture.seedFullInventory()

        await fixture.actor.deauthenticate()

        expectProfileStatePurged(
            storage: fixture.storage, keychain: fixture.keychain,
            snapshot: fixture.snapshot, dlqDirs: fixture.dlqDirs
        )
        #expect(fixture.purgeCount.count == 1)
        #expect(fixture.registrarCount.count == 0)  // no settings, no reconfigure
        // Still unconfigured afterwards: the purge needed no container.
        await #expect(throws: (any Error).self) {
            _ = try await fixture.actor.authManager()
        }
    }

    @Test("Deauth immediately after configure succeeds, purges, and reconfigures")
    func deauthImmediatelyAfterConfigurePurges() async throws {
        let fixture = try DeauthFixture()
        defer { fixture.cleanUp() }
        try fixture.seedFullInventory()
        // A decodable, unexpired session so configure runs the full
        // authenticated bring-up before deauthentication tears it down.
        try fixture.keychain.setObject(
            TokenResponse(profileToken: jwt(expiresIn: 3600), refreshToken: jwt(expiresIn: 86_400)),
            forKey: StorageKeys.Keychain.token.rawValue
        )

        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(fixture.box.manager?.armedSets == [[.sleep]])   // bring-up really ran

        await fixture.actor.deauthenticate()

        expectProfileStatePurged(
            storage: fixture.storage, keychain: fixture.keychain,
            snapshot: fixture.snapshot, dlqDirs: fixture.dlqDirs
        )
        #expect(fixture.purgeCount.count == 1)
        #expect(fixture.registrarCount.count == 2)  // initial configure + one reconfigure
        // Reconfigured and usable: the fresh container resolves.
        _ = try await fixture.actor.authManager()
    }

    @Test("A failing in-flight configure neither blocks deauth nor skips the purge")
    func failingConfigureDoesNotBlockDeauth() async throws {
        let gate = DeauthGate()
        let fixture = try DeauthFixture(failConfigure: true, configureGate: gate)
        defer { fixture.cleanUp() }
        try fixture.seedFullInventory()

        let configureTask = Task { try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox)) }
        let entered = await waitUntil { await gate.arrivals >= 1 }
        #expect(entered)

        let deauthTask = Task { await fixture.actor.deauthenticate() }
        // Deauth is now parked joining the gated configure; releasing the gate
        // fails the configure, and deauth must proceed to the purge anyway.
        await gate.open()
        await deauthTask.value

        await #expect(throws: (any Error).self) { try await configureTask.value }
        expectProfileStatePurged(
            storage: fixture.storage, keychain: fixture.keychain,
            snapshot: fixture.snapshot, dlqDirs: fixture.dlqDirs
        )
        #expect(fixture.purgeCount.count == 1)
        #expect(fixture.registrarCount.count == 2)  // failed configure + failed (swallowed) reconfigure
    }

    @Test("Concurrent double deauth joins one teardown: one purge, one reconfigure, no orphaned container")
    func concurrentDoubleDeauthJoins() async throws {
        let fixture = try DeauthFixture()
        defer { fixture.cleanUp() }
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(fixture.registrarCount.count == 1)

        async let first: Void = fixture.actor.deauthenticate()
        async let second: Void = fixture.actor.deauthenticate()
        _ = await (first, second)

        // A joined teardown runs one reset and one reconfigure; two interleaved
        // teardowns would reconfigure twice, orphaning an undisposed container.
        #expect(fixture.purgeCount.count == 1)
        #expect(fixture.registrarCount.count == 2)
        _ = try await fixture.actor.authManager()
    }

    @Test("An API call racing an in-flight deauth reports \"not configured\", never a DI resolution error")
    func apiCallDuringDeauthReportsNotConfigured() async throws {
        let disposeGate = DeauthGate()
        let fixture = try DeauthFixture(disposeGate: disposeGate)
        defer { fixture.cleanUp() }
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))
        // Resolve the gated pipeline so the container's reset must dispose it.
        _ = try await fixture.actor.tagPipeline()

        let deauthTask = Task { await fixture.actor.deauthenticate() }
        let parked = await waitUntil { await disposeGate.arrivals >= 1 }
        #expect(parked)   // deauth is now held mid-reset, container reference nilled

        do {
            _ = try await fixture.actor.authManager()
            Issue.record("resolution during deauth should have thrown")
        } catch let error as SahhaError {
            #expect(error.message.contains("not configured"))
            #expect(!error.message.contains("not registered"))
        }

        await disposeGate.open()
        await deauthTask.value
        // Teardown finished: the reconfigured actor resolves again.
        _ = try await fixture.actor.authManager()
    }

    @Test("A second deauth succeeds and leaves storage byte-identical")
    func secondDeauthIsIdempotent() async throws {
        let fixture = try DeauthFixture()
        defer { fixture.cleanUp() }
        try fixture.seedFullInventory()
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))

        await fixture.actor.deauthenticate()
        let keysAfterFirst = fixture.storage.allKeys().sorted()
        let deviceIdAfterFirst = fixture.storage.string(forKey: StorageKeys.UserDefaults.deviceId.rawValue)

        await fixture.actor.deauthenticate()

        #expect(fixture.storage.allKeys().sorted() == keysAfterFirst)
        #expect(fixture.storage.string(forKey: StorageKeys.UserDefaults.deviceId.rawValue) == deviceIdAfterFirst)
        #expect(deviceIdAfterFirst == "stable-device-id")
        #expect(fixture.keychain.storedKeys.isEmpty)
        #expect(fixture.purgeCount.count == 2)
        #expect(fixture.registrarCount.count == 3)  // configure + one reconfigure per deauth
    }

    @Test("Deauth during an in-flight authenticate: keychain empty, snapshot cleared, authenticate reports failure")
    func deauthDuringInFlightAuthenticate() async throws {
        let service = GatedAuthService()
        let fixture = try DeauthFixture(authService: service)
        defer { fixture.cleanUp() }
        fixture.snapshot.profileToken = "stale-token"
        fixture.snapshot.profileId = "stale-id"
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))

        let authTask = Task { () -> Bool in
            do {
                let manager = try await fixture.actor.authManager()
                try await manager.authenticate(appId: "app", appSecret: "secret", externalId: "external")
                return true
            } catch {
                return false
            }
        }
        let entered = await waitUntil { await service.entered }
        #expect(entered)

        await fixture.actor.deauthenticate()
        // The service answers after teardown: the token save must hit the
        // disposed store and fail the authenticate, not resurrect a session.
        await service.release(.success(
            TokenResponse(profileToken: jwt(expiresIn: 3600), refreshToken: jwt(expiresIn: 86_400))
        ))

        let succeeded = await authTask.value
        #expect(succeeded == false)
        #expect(fixture.keychain.storedKeys.isEmpty)
        #expect(fixture.snapshot.profileToken == nil)
        #expect(fixture.snapshot.profileId == nil)
    }

    @Test("Deauth then re-auth: the store is empty, resume arms nothing, a fresh enable works")
    func deauthThenReauthStartsClean() async throws {
        let service = MockAuthService(authenticate: [
            { TokenResponse(profileToken: jwt(expiresIn: 3600), refreshToken: jwt(expiresIn: 86_400)) },
        ])
        let fixture = try DeauthFixture(authService: service)
        defer { fixture.cleanUp() }
        fixture.storage.set(
            try JSONEncoder().encode(["sleep"]),
            forKey: StorageKeys.UserDefaults.sensors.rawValue
        )
        try fixture.keychain.setObject(
            TokenResponse(profileToken: jwt(expiresIn: 3600), refreshToken: jwt(expiresIn: 86_400)),
            forKey: StorageKeys.Keychain.token.rawValue
        )
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(fixture.box.manager?.armedSets == [[.sleep]])

        await fixture.actor.deauthenticate()
        #expect(fixture.storage.get(forKey: StorageKeys.UserDefaults.sensors.rawValue) == nil)

        // Re-authenticate against the fresh container and run the bring-up.
        let manager = try await fixture.actor.authManager()
        try await manager.authenticate(appId: "app", appSecret: "secret", externalId: "external")
        try await fixture.actor.startAuthenticatedServices()

        let freshManager = try #require(fixture.box.manager)
        // Resume found an empty store: nothing was armed from stale state.
        let armedNothing = freshManager.armedSets.allSatisfy(\.isEmpty)
        #expect(armedNothing)
        // And the fresh store accepts writes: enable works end-to-end.
        try await freshManager.enableSensors([.steps])
        #expect(fixture.storage.get(forKey: StorageKeys.UserDefaults.sensors.rawValue) != nil)
    }
}
