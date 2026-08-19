import Testing
import Foundation
import HealthKit

@testable import Sahha

// Coverage for the deferred authenticated bring-up (PRD #76 D10).
//
// A launch that cannot resolve its session no longer collapses to "not
// authenticated": the gate now produces a five-way verdict, and the two
// deferrable verdicts (transient refresh failure, unreadable token store) arm an
// event-driven retry — lifecycle events, first unlock, a network transition, and
// a token-refresh piggyback — governed by a pure backoff policy with no timers.
//
// Three layers, mirroring the design:
// - `BringUpRetryPolicy` is pure and tested with explicit timestamps;
// - verdict classification runs against the real `AuthManager` (and, for the
//   unreadable verdict, the real `TokenStore` — which writes the process-global
//   `Sahha.authSnapshot`; no other suite asserts on that global, so this stays
//   parallel-safe);
// - actor-level tests use the non-shared `SahhaActor` seam with a
//   test-controlled `NetworkMonitor`, an observer spy, and a recording
//   HealthKit-manager double, so no NotificationCenter observer or live
//   NWPathMonitor ever starts.

// MARK: - Helpers

private func apiError(_ statusCode: Int) -> APIErrorResponse {
    APIErrorResponse(title: "HTTP \(statusCode)", statusCode: statusCode, location: "test", errors: [])
}

private func seedSensors(_ storage: InMemoryStorage, rawValues: [String]) throws {
    storage.set(try JSONEncoder().encode(rawValues), forKey: StorageKeys.UserDefaults.sensors.rawValue)
}

private func seedKeychainToken(
    _ keychain: MockKeychainStorage,
    profileToken: String,
    refreshToken: String
) throws {
    try keychain.setObject(
        TokenResponse(profileToken: profileToken, refreshToken: refreshToken),
        forKey: StorageKeys.Keychain.token.rawValue
    )
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

/// Lets in-flight fire-and-forget work (piggyback tasks, monitor callbacks) land
/// before asserting that nothing further happened.
private func settle() async {
    try? await Task.sleep(nanoseconds: 300_000_000)
}

// MARK: - Retry policy (pure)

@Suite("Bring-up retry policy (D10)")
struct BringUpRetryPolicyTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test("Arming opens a positive first window; a dormant machine admits nothing")
    func armOpensPositiveFirstWindow() {
        var policy = BringUpRetryPolicy()
        #expect(policy.admitTrigger(at: t0) == false)   // dormant: never admits

        policy.arm(at: t0, jitter: 1.0)
        #expect(policy.isArmed)
        #expect(policy.admitTrigger(at: t0) == false)                       // instantly: gated
        #expect(policy.admitTrigger(at: t0.addingTimeInterval(29.9)) == false)
        #expect(policy.admitTrigger(at: t0.addingTimeInterval(30)) == true) // window open
    }

    @Test("Completion latches: nothing is admitted afterwards, not even a bypass")
    func completedLatches() {
        var policy = BringUpRetryPolicy()
        policy.arm(at: t0, jitter: 1.0)
        let admitted = policy.admitTrigger(at: t0.addingTimeInterval(30))
        #expect(admitted)
        policy.recordSuccess()

        #expect(policy.state == .completed)
        #expect(policy.admitTrigger(at: t0.addingTimeInterval(3600)) == false)
        policy.noteStateChange(resettingAttempts: true)
        #expect(policy.admitTrigger(at: t0.addingTimeInterval(7200)) == false)
        policy.arm(at: t0.addingTimeInterval(7200), jitter: 1.0)             // must not resurrect
        #expect(policy.state == .completed)
    }

    @Test("A stood-down machine is dormant and can be re-armed")
    func standDownReturnsToDormant() {
        var policy = BringUpRetryPolicy()
        policy.arm(at: t0, jitter: 1.0)
        policy.standDown()
        #expect(policy.state == .dormant)
        #expect(policy.admitTrigger(at: t0.addingTimeInterval(3600)) == false)

        policy.arm(at: t0.addingTimeInterval(3600), jitter: 1.0)
        #expect(policy.isArmed)
    }

    @Test("Backoff doubles monotonically from 30s to the 15-minute cap")
    func backoffIsMonotonicToCap() throws {
        var policy = BringUpRetryPolicy()
        policy.arm(at: t0, jitter: 1.0)
        let firstWindow = try #require(policy.windowOpensAt)
        #expect(firstWindow.timeIntervalSince(t0) == 30)

        var now = firstWindow
        var delays: [TimeInterval] = []
        for _ in 0..<7 {
            let admitted = policy.admitTrigger(at: now)
            #expect(admitted)
            policy.recordFailure(at: now, jitter: 1.0)
            let next = try #require(policy.windowOpensAt)
            delays.append(next.timeIntervalSince(now))
            now = next
        }
        #expect(delays == [60, 120, 240, 480, 900, 900, 900])
    }

    @Test("Jitter keeps every window within ±25% of its base")
    func jitterStaysWithinBounds() throws {
        for _ in 0..<100 {
            var policy = BringUpRetryPolicy()
            policy.arm(at: t0)                                   // default (random) jitter
            let armDelay = try #require(policy.windowOpensAt).timeIntervalSince(t0)
            #expect(armDelay >= 22.5 && armDelay <= 37.5)        // 30 ± 25%

            let admitted = policy.admitTrigger(at: t0.addingTimeInterval(40))
            #expect(admitted)
            let failedAt = t0.addingTimeInterval(40)
            policy.recordFailure(at: failedAt)                   // base 60
            let retryDelay = try #require(policy.windowOpensAt).timeIntervalSince(failedAt)
            #expect(retryDelay >= 45 && retryDelay <= 75)        // 60 ± 25%
        }
    }

    @Test("The 5s floor collapses rapid triggers and is never bypassed")
    func floorCollapsesRapidTriggers() {
        var policy = BringUpRetryPolicy()
        policy.arm(at: t0, jitter: 1.0)
        let attemptAt = t0.addingTimeInterval(30)
        let admitted = policy.admitTrigger(at: attemptAt)
        #expect(admitted)
        policy.recordFailure(at: attemptAt, jitter: 1.0)         // next window +60s

        policy.noteStateChange(resettingAttempts: false)
        // 2s after the attempt: the floor blocks even a bypass — and retains it.
        #expect(policy.admitTrigger(at: attemptAt.addingTimeInterval(2)) == false)
        #expect(policy.bypassPending)
        // 6s after: floor passed, bypass consumed, window ignored.
        #expect(policy.admitTrigger(at: attemptAt.addingTimeInterval(6)) == true)
    }

    @Test("The 8-attempt budget holds; a network transition grants a fresh one")
    func attemptCapHoldsAndNetworkResets() {
        var policy = BringUpRetryPolicy()
        policy.arm(at: t0, jitter: 1.0)
        var now = t0
        for _ in 0..<8 {
            now = now.addingTimeInterval(86_400)                 // clear any window
            let admitted = policy.admitTrigger(at: now)
            #expect(admitted)
            policy.recordFailure(at: now, jitter: 1.0)
        }
        #expect(policy.admitTrigger(at: now.addingTimeInterval(86_400)) == false)

        policy.noteStateChange(resettingAttempts: true)
        #expect(policy.admitTrigger(at: now.addingTimeInterval(172_800)) == true)
    }

    @Test("A bypass admits exactly one out-of-window trigger")
    func bypassIsConsumedOnce() {
        var policy = BringUpRetryPolicy()
        policy.arm(at: t0, jitter: 1.0)
        policy.noteStateChange(resettingAttempts: false)

        #expect(policy.admitTrigger(at: t0.addingTimeInterval(1)) == true)   // bypassed the 30s window
        policy.recordFailure(at: t0.addingTimeInterval(1), jitter: 1.0)
        // Floor passed, window (t0+61) still closed, bypass spent: gated again.
        #expect(policy.admitTrigger(at: t0.addingTimeInterval(7)) == false)
    }

    @Test("The production scheduling constants are pinned")
    func productionConstantsArePinned() {
        #expect(BringUpRetryPolicy.initialDelay == 30)
        #expect(BringUpRetryPolicy.maxDelay == 900)
        #expect(BringUpRetryPolicy.jitterSpread == 0.25)
        #expect(BringUpRetryPolicy.interAttemptFloor == 5)
        #expect(BringUpRetryPolicy.maxAttempts == 8)
    }
}

// MARK: - Verdict classification (real auth manager)

@Suite("Launch auth verdict (D10)")
struct LaunchAuthVerdictTests {
    private let validRefreshJWT = jwt(expiresIn: 86_400)

    private func make(
        token: TokenResponse?,
        service: MockAuthService
    ) -> (AuthManager, MockTokenStore) {
        let store = MockTokenStore(token)
        let manager = AuthManager(
            authService: service,
            tokenStore: store,
            logger: NoopErrorLogger()
        )
        return (manager, store)
    }

    @Test("A valid stored token is .valid with zero network calls")
    func validTokenIsValid() async throws {
        let service = MockAuthService(failure: apiError(401))    // must never be called
        let (manager, _) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: 3600), refreshToken: validRefreshJWT),
            service: service
        )

        #expect(await manager.launchVerdict() == .valid)
        #expect(await service.refreshCallCount == 0)
    }

    @Test("A cleanly empty store is .unauthenticated with zero network calls")
    func emptyStoreIsUnauthenticated() async throws {
        let service = MockAuthService(failure: apiError(401))    // must never be called
        let (manager, _) = make(token: nil, service: service)

        #expect(await manager.launchVerdict() == .unauthenticated)
        #expect(await service.refreshCallCount == 0)
    }

    @Test(
        "Recoverable refresh failures are .transientRefreshFailure and keep the tokens",
        arguments: [400, 404, 408, 429, 500, -1]
    )
    func transientFailuresKeepTokens(statusCode: Int) async throws {
        let service = MockAuthService(failure: apiError(statusCode))
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        #expect(await manager.launchVerdict() == .transientRefreshFailure)
        #expect(await store.token() != nil)
        #expect(await store.clearCount == 0)
    }

    @Test("An offline refresh (transport error) is .transientRefreshFailure and keeps the tokens")
    func offlineIsTransient() async throws {
        let service = MockAuthService(refresh: [{ throw URLError(.notConnectedToInternet) }])
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        #expect(await manager.launchVerdict() == .transientRefreshFailure)
        #expect(await store.token() != nil)
    }

    @Test(
        "Authoritative rejections are .terminalSessionExpiry and clear the tokens",
        arguments: [401, 403]
    )
    func terminalFailuresClearTokens(statusCode: Int) async throws {
        let service = MockAuthService(failure: apiError(statusCode))
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: validRefreshJWT),
            service: service
        )

        #expect(await manager.launchVerdict() == .terminalSessionExpiry)
        #expect(await store.token() == nil)
        #expect(await store.clearCount == 1)
    }

    @Test("An expired refresh JWT is terminal with zero network calls")
    func expiredRefreshJWTIsTerminalOffline() async throws {
        let service = MockAuthService(failure: apiError(401))    // must never be called
        let (manager, store) = make(
            token: TokenResponse(profileToken: jwt(expiresIn: -10), refreshToken: jwt(expiresIn: -300)),
            service: service
        )

        #expect(await manager.launchVerdict() == .terminalSessionExpiry)
        #expect(await service.refreshCallCount == 0)
        #expect(await store.clearCount == 1)
    }

    @Test("An unreadable keychain is the distinct store-unreadable verdict, and recovers after reload")
    func unreadableKeychainRecoversAfterReload() async throws {
        let keychain = MockKeychainStorage()
        try seedKeychainToken(keychain, profileToken: jwt(expiresIn: 3600), refreshToken: jwt(expiresIn: 86_400))
        keychain.errorToThrow = NSError(domain: "test.keychain", code: -25308)

        // The init-time read fails: nil token + latched unreadable state.
        let store = TokenStore(storage: keychain, logger: NoopErrorLogger())
        let service = MockAuthService(failure: apiError(401))    // must never be called
        let manager = AuthManager(authService: service, tokenStore: store, logger: NoopErrorLogger())

        #expect(await manager.launchVerdict() == .tokenStoreUnreadable)

        // Protected data becomes available: the reload recovers the session.
        keychain.errorToThrow = nil
        await store.reloadPersistedSession()

        #expect(await manager.launchVerdict() == .valid)
        #expect(await service.refreshCallCount == 0)
        #expect(await store.hasUnreadablePersistedSession() == false)
    }

    @Test("A reload that still cannot read keeps the store-unreadable verdict")
    func failedReloadStaysUnreadable() async throws {
        let keychain = MockKeychainStorage()
        try seedKeychainToken(keychain, profileToken: jwt(expiresIn: 3600), refreshToken: jwt(expiresIn: 86_400))
        keychain.errorToThrow = NSError(domain: "test.keychain", code: -25308)

        let store = TokenStore(storage: keychain, logger: NoopErrorLogger())
        let manager = AuthManager(
            authService: MockAuthService(failure: apiError(401)),
            tokenStore: store,
            logger: NoopErrorLogger()
        )

        await store.reloadPersistedSession()                     // keychain still locked
        #expect(await manager.launchVerdict() == .tokenStoreUnreadable)
    }
}

// MARK: - Actor-level doubles

/// Records every request and succeeds plain sends; nothing in these tests
/// asserts on network traffic.
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

/// HealthKit-manager double for this suite: resume calls are recorded (the
/// "collection started" signal) and leave real observer-store bookkeeping
/// behind, so the bring-up tail's health check finds a healthy store instead of
/// demanding repairs.
private final class ArmRecordingManager: HealthKitManagerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let sensorStore: SensorStoreProtocol
    private let observerStore: HealthKitObserverStoreProtocol
    private var _resumeCalls = 0
    private var _resumeForCalls: [Set<SahhaSensor>] = []
    private var _armedSets: [Set<SahhaSensor>] = []

    var resumeCalls: Int {
        lock.lock(); defer { lock.unlock() }
        return _resumeCalls
    }

    var resumeForCalls: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _resumeForCalls
    }

    var armedSets: [Set<SahhaSensor>] {
        lock.lock(); defer { lock.unlock() }
        return _armedSets
    }

    init(sensorStore: SensorStoreProtocol, observerStore: HealthKitObserverStoreProtocol) {
        self.sensorStore = sensorStore
        self.observerStore = observerStore
    }

    func resumeSensors() async {
        recordResume()
        guard let sensors = try? await sensorStore.getSensors() else { return }
        await arm(sensors)
    }

    func resumeSensors(for sensors: Set<SahhaSensor>) async {
        recordResumeFor(sensors)
        await arm(sensors)
    }

    private func recordResume() {
        lock.lock(); defer { lock.unlock() }
        _resumeCalls += 1
    }

    private func recordResumeFor(_ sensors: Set<SahhaSensor>) {
        lock.lock(); defer { lock.unlock() }
        _resumeForCalls.append(sensors)
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

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {}
    func querySensors() async -> PostSensorDataResult { PostSensorDataResult(sensorResults: []) }
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus { .pending }
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] { [] }
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] { [] }
    func getDemographic() async throws -> SahhaDemographic { SahhaDemographic() }
    func postInsights() async {}
}

/// Hands the registrar-built manager double back to the test. Stays nil until a
/// bring-up actually resolves the HealthKit manager — which makes it double as
/// the "no collection machinery was ever touched" assertion.
private final class ManagerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _manager: ArmRecordingManager?

    var manager: ArmRecordingManager? {
        lock.lock(); defer { lock.unlock() }
        return _manager
    }

    func set(_ manager: ArmRecordingManager) {
        lock.lock(); defer { lock.unlock() }
        _manager = manager
    }
}

/// Counts factory invocations and hands out one shared test-controlled monitor,
/// so "started only while deferred" is directly observable.
private final class MonitorFactory: @unchecked Sendable {
    private let lock = NSLock()
    private let monitor: NetworkMonitor
    private var _callCount = 0

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _callCount
    }

    init(monitor: NetworkMonitor) {
        self.monitor = monitor
    }

    func make() -> NetworkMonitor {
        lock.lock(); defer { lock.unlock() }
        _callCount += 1
        return monitor
    }
}

private func makeActor(
    storage: InMemoryStorage,
    keychain: MockKeychainStorage,
    authService: MockAuthService,
    spy: LifecycleObserverSpy,
    monitorFactory: MonitorFactory,
    managerBox: ManagerBox
) -> SahhaActor {
    SahhaActor(
        registrar: { container, settings in
            await SahhaActor.registerProductionDependencies(container: container, settings: settings)
            await container.register(UserDefaultsStorageProtocol.self) { _ in storage }
            await container.register(KeychainStorageProtocol.self) { _ in keychain }
            await container.register(ErrorLoggerProtocol.self) { _ in RecordingErrorLogger() }
            await container.register(APIClientProtocol.self) { _ in NullAPIClient() }
            await container.register(AuthServiceProtocol.self) { _ in authService }
            await container.register(HealthKitSampleQueryServiceProtocol.self) { _ in EmptySampleQueryService() }
            await container.register(HealthKitManagerProtocol.self) { container in
                let manager = ArmRecordingManager(
                    sensorStore: try await container.resolve(SensorStoreProtocol.self),
                    observerStore: try await container.resolve(HealthKitObserverStoreProtocol.self)
                )
                managerBox.set(manager)
                return manager
            }
        },
        lifecycleObserver: spy,
        retryMonitorFactory: { monitorFactory.make() },
        // This suite asserts dispose-driven teardown only; a no-op purge keeps
        // deauthentication off the process-global storage. The purge itself is
        // covered by DeauthenticationTests.
        purge: {}
    )
}

// MARK: - Actor-level suite

@Suite("Deferred bring-up retry (D10)")
struct DeferredBringUpRetryTests {

    /// The offline-launch fixture: a stored session whose profile token is
    /// expired, a refresh that fails offline once and then succeeds, and a
    /// test-controlled monitor that starts disconnected.
    private struct OfflineFixture {
        let storage: InMemoryStorage
        let keychain: MockKeychainStorage
        let spy: LifecycleObserverSpy
        let box: ManagerBox
        let monitor: NetworkMonitor
        let factory: MonitorFactory
        let service: MockAuthService
        let staleRefresh: String
        let freshProfile: String
        let rotatedRefresh: String
        let actor: SahhaActor

        init() throws {
            let storage = InMemoryStorage()
            let keychain = MockKeychainStorage()
            let monitor = NetworkMonitor(isConnected: false)
            let staleRefresh = jwt(expiresIn: 86_400)
            let freshProfile = jwt(expiresIn: 3600)
            let rotatedRefresh = jwt(expiresIn: 172_800)
            try seedSensors(storage, rawValues: ["sleep"])
            try seedKeychainToken(keychain, profileToken: jwt(expiresIn: -10), refreshToken: staleRefresh)
            let service = MockAuthService(refresh: [
                { throw URLError(.notConnectedToInternet) },
                { TokenResponse(profileToken: freshProfile, refreshToken: rotatedRefresh) },
            ])
            let spy = LifecycleObserverSpy()
            let box = ManagerBox()
            let factory = MonitorFactory(monitor: monitor)

            self.storage = storage
            self.keychain = keychain
            self.spy = spy
            self.box = box
            self.monitor = monitor
            self.factory = factory
            self.service = service
            self.staleRefresh = staleRefresh
            self.freshProfile = freshProfile
            self.rotatedRefresh = rotatedRefresh
            self.actor = makeActor(
                storage: storage,
                keychain: keychain,
                authService: service,
                spy: spy,
                monitorFactory: factory,
                managerBox: box
            )
        }
    }

    @Test("An offline launch defers bring-up with tokens retained; a network transition recovers it")
    func offlineLaunchDefersAndNetworkTransitionRecovers() async throws {
        let fixture = try OfflineFixture()

        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))

        // Deferred: the collection machinery was never even constructed, the
        // stored pair survived the transient failure, and the dedicated monitor
        // is up.
        #expect(fixture.box.manager == nil)
        let retained: TokenResponse? = try fixture.keychain.object(forKey: StorageKeys.Keychain.token.rawValue)
        #expect(retained?.refreshToken == fixture.staleRefresh)
        #expect(fixture.factory.callCount == 1)

        // Connectivity returns: the transition bypasses the backoff window and
        // the deferred bring-up runs — observers armed, rotated pair persisted.
        await fixture.monitor.setConnectedForTesting(true)

        let recovered = await waitUntil { fixture.box.manager?.resumeCalls == 1 }
        #expect(recovered)
        let manager = try #require(fixture.box.manager)
        #expect(manager.armedSets == [[.sleep]])
        #expect(manager.resumeForCalls.isEmpty)     // tail health check found a healthy store
        let stored: TokenResponse? = try fixture.keychain.object(forKey: StorageKeys.Keychain.token.rawValue)
        #expect(stored?.profileToken == fixture.freshProfile)
        #expect(stored?.refreshToken == fixture.rotatedRefresh)
        #expect(await fixture.service.refreshCallCount == 2)
    }

    @Test("Post-completion triggers are no-ops")
    func postCompletionTriggersAreNoOps() async throws {
        let fixture = try OfflineFixture()
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))
        await fixture.monitor.setConnectedForTesting(true)
        let recovered = await waitUntil { fixture.box.manager?.resumeCalls == 1 }
        #expect(recovered)
        // Completion disposes the monitor (its callback registry empties);
        // waiting for that pins "the machine is latched" before poking it.
        let completed = await waitUntil { await fixture.monitor.registeredCallbackCount == 0 }
        #expect(completed)

        await fixture.spy.fire(.app_resume)
        await fixture.spy.fire(.app_foreground)
        await fixture.spy.fire(.app_unlocked)
        await fixture.monitor.setConnectedForTesting(false)
        await fixture.monitor.setConnectedForTesting(true)
        await settle()

        #expect(fixture.box.manager?.resumeCalls == 1)
        #expect(fixture.factory.callCount == 1)     // the monitor was never restarted
    }

    @Test("A retry racing the authenticate path produces exactly one bring-up")
    func retryRacingAuthenticateProducesOneBringUp() async throws {
        let fixture = try OfflineFixture()
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))

        // The authenticate door and the network-transition retry race: whichever
        // order the actor serializes them in, the shared single-flight latch
        // admits exactly one bring-up pass.
        async let authenticateDoor: Void = fixture.actor.startAuthenticatedServices()
        async let networkTrigger: Void = fixture.monitor.setConnectedForTesting(true)
        try await authenticateDoor
        await networkTrigger

        _ = await waitUntil { fixture.box.manager?.resumeCalls ?? 0 >= 1 }
        await settle()
        #expect(fixture.box.manager?.resumeCalls == 1)
    }

    @Test("Concurrent triggers produce exactly one bring-up")
    func concurrentTriggersProduceOneBringUp() async throws {
        let fixture = try OfflineFixture()
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await fixture.spy.fire(.app_foreground) }
            group.addTask { await fixture.spy.fire(.app_resume) }
            group.addTask { await fixture.monitor.setConnectedForTesting(true) }
        }

        _ = await waitUntil { fixture.box.manager?.resumeCalls ?? 0 >= 1 }
        await settle()
        #expect(fixture.box.manager?.resumeCalls == 1)
    }

    @Test("A successful token refresh anywhere drives exactly one deferred bring-up, without deadlock")
    func refreshPiggybackDrivesOneBringUp() async throws {
        let fixture = try OfflineFixture()
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(fixture.box.manager == nil)

        // Any API call would do this internally: the interceptor refreshes the
        // expired token, the refresh succeeds, and the piggyback completes the
        // deferred bring-up — no lifecycle or network event involved.
        let authManager = try await fixture.actor.authManager()
        _ = try await authManager.getValidProfileToken()

        let recovered = await waitUntil { fixture.box.manager?.resumeCalls == 1 }
        #expect(recovered)
        await settle()
        #expect(fixture.box.manager?.resumeCalls == 1)
        // The piggybacked attempt answered its verdict from the just-saved
        // token: launch probe + this refresh, and nothing more.
        #expect(await fixture.service.refreshCallCount == 2)
    }

    @Test("An unreadable token store defers, then recovers on the unlock event via reload")
    func unreadableStoreRecoversOnUnlock() async throws {
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: ["sleep"])
        let keychain = MockKeychainStorage()
        try seedKeychainToken(keychain, profileToken: jwt(expiresIn: 3600), refreshToken: jwt(expiresIn: 86_400))
        keychain.errorToThrow = NSError(domain: "test.keychain", code: -25308)
        let service = MockAuthService(refresh: [])                          // refresh must never be needed
        let spy = LifecycleObserverSpy()
        let box = ManagerBox()
        let factory = MonitorFactory(monitor: NetworkMonitor(isConnected: false))
        let actor = makeActor(
            storage: storage,
            keychain: keychain,
            authService: service,
            spy: spy,
            monitorFactory: factory,
            managerBox: box
        )

        try await actor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(box.manager == nil)                              // deferred, nothing started
        #expect(factory.callCount == 1)                          // deferral started the monitor

        // First unlock: protected data is available again. The unlock trigger is
        // not gated by the network backoff window — the spy delivers the event
        // synchronously, so the whole reload-and-bring-up attempt has completed
        // by the time fire returns.
        keychain.errorToThrow = nil
        await spy.fire(.app_unlocked)

        let manager = try #require(box.manager)
        #expect(manager.resumeCalls == 1)
        #expect(manager.armedSets == [[.sleep]])
        #expect(await service.refreshCallCount == 0)             // recovery was purely local
    }

    @Test("The retry listener registers before the auth gate and is deduped across configures")
    func retryListenerRegistersPreGateAndDedupes() async throws {
        // An unauthenticated launch: the gate declines, no authenticated
        // listeners register — the retry registration below can only have
        // happened before the gate.
        let spy = LifecycleObserverSpy()
        let actor = makeActor(
            storage: InMemoryStorage(),
            keychain: MockKeychainStorage(),
            authService: MockAuthService(refresh: []),
            spy: spy,
            monitorFactory: MonitorFactory(monitor: NetworkMonitor(isConnected: true)),
            managerBox: ManagerBox()
        )
        let retryEvents: Set<LifecycleEvent> = [.app_resume, .app_foreground, .app_unlocked]

        try await actor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(await spy.registeredEvents().filter { $0 == retryEvents }.count == 1)

        // Reconfiguring must not stack a second registration.
        try await actor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(await spy.registeredEvents().filter { $0 == retryEvents }.count == 1)
    }

    @Test("The monitor starts only while deferred and stops on completion")
    func monitorStartsOnDeferralAndStopsOnCompletion() async throws {
        // Unauthenticated launch: no deferral, no monitor.
        let unauthedFactory = MonitorFactory(monitor: NetworkMonitor(isConnected: true))
        let unauthedActor = makeActor(
            storage: InMemoryStorage(),
            keychain: MockKeychainStorage(),
            authService: MockAuthService(refresh: []),
            spy: LifecycleObserverSpy(),
            monitorFactory: unauthedFactory,
            managerBox: ManagerBox()
        )
        try await unauthedActor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(unauthedFactory.callCount == 0)

        // Deferred launch: the monitor is up and holds the actor's retry
        // callback; completing the bring-up disposes it, emptying the registry.
        let fixture = try OfflineFixture()
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(fixture.factory.callCount == 1)
        #expect(await fixture.monitor.registeredCallbackCount == 1)

        await fixture.monitor.setConnectedForTesting(true)
        let recovered = await waitUntil { fixture.box.manager?.resumeCalls == 1 }
        #expect(recovered)
        let stopped = await waitUntil { await fixture.monitor.registeredCallbackCount == 0 }
        #expect(stopped)
        #expect(fixture.factory.callCount == 1)                  // never restarted
    }

    @Test("Deauthentication stops the monitor and the fresh configure stays dormant")
    func deauthenticationStopsMonitor() async throws {
        let fixture = try OfflineFixture()
        try await fixture.actor.configure(with: SahhaSettings(environment: .sandbox))
        #expect(fixture.factory.callCount == 1)
        #expect(await fixture.monitor.registeredCallbackCount == 1)

        // Deauthentication stops the monitor explicitly (it lives outside the
        // container) and wipes the keychain, so the re-configure inside it reads
        // a clean signed-out store: dormant machine, no second monitor.
        await fixture.actor.deauthenticate()
        #expect(fixture.factory.callCount == 1)
        #expect(await fixture.monitor.registeredCallbackCount == 0)

        await fixture.monitor.setConnectedForTesting(true)
        await settle()
        #expect(fixture.box.manager == nil)                      // nothing ever started
    }

    @Test("A terminal launch verdict clears the session and never arms a retry")
    func terminalLaunchNeverArms() async throws {
        let storage = InMemoryStorage()
        try seedSensors(storage, rawValues: ["sleep"])
        let keychain = MockKeychainStorage()
        try seedKeychainToken(keychain, profileToken: jwt(expiresIn: -10), refreshToken: jwt(expiresIn: 86_400))
        let service = MockAuthService(failure: apiError(401))
        let spy = LifecycleObserverSpy()
        let box = ManagerBox()
        let factory = MonitorFactory(monitor: NetworkMonitor(isConnected: false))
        let actor = makeActor(
            storage: storage,
            keychain: keychain,
            authService: service,
            spy: spy,
            monitorFactory: factory,
            managerBox: box
        )

        try await actor.configure(with: SahhaSettings(environment: .sandbox))

        #expect(factory.callCount == 0)                          // never deferred
        #expect(keychain.storedKeys.contains(StorageKeys.Keychain.token.rawValue) == false)  // session cleared

        await spy.fire(.app_resume)
        await spy.fire(.app_unlocked)
        await settle()
        #expect(box.manager == nil)                              // nothing was ever brought up
    }
}
