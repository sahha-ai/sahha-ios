import Testing
import Foundation
@testable import Sahha

/// PRD #76 D13a: auth-gated public calls await the in-flight configuration
/// before proceeding. The await's original job (waiting for configure to
/// populate the old auth cache) is gone — the guard now reads the persisted
/// session directly — but the box's synchronous capture still closes the
/// configure→actor-entry race: a gated call issued right after `configure()`
/// could otherwise reach the actor before the configure task registers there
/// and throw "not configured". These tests keep the await order pinned.
///
/// Every test runs against a private `ConfigurationTaskBox`, a private
/// injected `SessionReading` fake, and a fresh non-shared `SahhaActor` (never
/// configured, so its error logging stays inert) — nothing touches the
/// facade's global session seam (SessionTruthTests owns that) or the facade's
/// global box (the shared-actor test in SahhaTests.swift covers the capture
/// wiring). That keeps the suite parallel-safe without `.serialized`.
@Suite("Auth-gated calls await configuration (D13a)")
struct AuthGatedConfigurationAwaitTests {

    // MARK: - The race (acceptance criterion 1)

    @Test("A call during an in-flight configure is judged on the resolved auth state (value overload)")
    func gatedCallAwaitsInFlightConfigureValueOverload() async throws {
        let session = FakeSessionReader()
        let box = ConfigurationTaskBox()
        let gate = DeauthGate()
        // Stand-in for a configure that lands a session before resolving: the
        // reader authenticates only once the gate opens, so an eager guard
        // (judging before the awaited configure finished) is observable.
        box.capture(Task {
            await gate.waitUntilOpen()
            session.setProfileToken("restored-session-token")
        })

        let recorder = CallbackRecorder<Int>()
        Sahha.runAsyncWithCallback(
            callback: { recorder.record($0, $1) },
            requiresAuth: true,
            configurationTaskBox: box,
            session: session,
            actor: SahhaActor(),
            task: { 42 },
            defaultErrorValue: -1
        )

        // Give a wrongly-eager guard every chance to fire: judged before the
        // configure resolved, the still-unauthenticated reader would have
        // produced an "Unauthorized" callback well within this window.
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(recorder.count == 0)

        await gate.open()

        let fired = await waitUntil { recorder.count == 1 }
        #expect(fired)
        let outcome = try #require(recorder.first)
        #expect(outcome.0 == nil)
        #expect(outcome.1 == 42)
    }

    @Test("A call during an in-flight configure is judged on the resolved auth state (optional overload)")
    func gatedCallAwaitsInFlightConfigureOptionalOverload() async throws {
        let session = FakeSessionReader()
        let box = ConfigurationTaskBox()
        let gate = DeauthGate()
        box.capture(Task {
            await gate.waitUntilOpen()
            session.setProfileToken("restored-session-token")
        })

        let recorder = CallbackRecorder<String?>()
        Sahha.runAsyncWithCallback(
            callback: { recorder.record($0, $1) },
            requiresAuth: true,
            configurationTaskBox: box,
            session: session,
            actor: SahhaActor(),
            task: { "scores-payload" }
        )

        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(recorder.count == 0)

        await gate.open()

        let fired = await waitUntil { recorder.count == 1 }
        #expect(fired)
        let outcome = try #require(recorder.first)
        #expect(outcome.0 == nil)
        #expect(outcome.1 == "scores-payload")
    }

    // MARK: - The unchanged error contract (acceptance criterion 2)

    @Test("A genuinely unauthenticated caller keeps the exact error contract (value overload)")
    func unauthenticatedContractUnchangedValueOverload() async {
        let session = FakeSessionReader()  // signed out
        let box = ConfigurationTaskBox()
        // A configure that ran and resolved without producing a session.
        box.capture(Task {})

        let outcome: (String?, Int) = await withCheckedContinuation { (continuation: CheckedContinuation<(String?, Int), Never>) in
            Sahha.runAsyncWithCallback(
                callback: { continuation.resume(returning: ($0, $1)) },
                requiresAuth: true,
                configurationTaskBox: box,
                session: session,
                actor: SahhaActor(),
                task: { 42 },
                defaultErrorValue: -1
            )
        }

        #expect(outcome.0 == "Unauthorized. Please call `Sahha.authenticate(...)` first.")
        #expect(outcome.1 == -1)  // the default value, never the task's result
    }

    @Test("A genuinely unauthenticated caller keeps the exact error contract (optional overload)")
    func unauthenticatedContractUnchangedOptionalOverload() async {
        let session = FakeSessionReader()
        let box = ConfigurationTaskBox()
        box.capture(Task {})

        let outcome: (String?, String?) = await withCheckedContinuation { (continuation: CheckedContinuation<(String?, String?), Never>) in
            Sahha.runAsyncWithCallback(
                callback: { continuation.resume(returning: ($0, $1)) },
                requiresAuth: true,
                configurationTaskBox: box,
                session: session,
                actor: SahhaActor(),
                task: { "never-produced" }
            )
        }

        #expect(outcome.0 == "Unauthorized. Please call `Sahha.authenticate(...)` first.")
        #expect(outcome.1 == nil)
    }

    // MARK: - Before any configure (acceptance criterion 3)

    @Test("A signed-out call before any configure evaluates the guard immediately")
    func preConfigureCallDoesNotHang() async {
        let session = FakeSessionReader()
        let box = ConfigurationTaskBox()  // nothing ever captured

        let outcome: (String?, Int) = await withCheckedContinuation { (continuation: CheckedContinuation<(String?, Int), Never>) in
            Sahha.runAsyncWithCallback(
                callback: { continuation.resume(returning: ($0, $1)) },
                requiresAuth: true,
                configurationTaskBox: box,
                session: session,
                actor: SahhaActor(),
                task: { 9 },
                defaultErrorValue: -1
            )
        }

        // Completing at all proves the empty box falls through rather than
        // hanging; a signed-OUT pre-configure call keeps today's unauthorized
        // contract exactly. (A signed-IN pre-configure call now passes this
        // guard and reports "not configured" instead — pinned by
        // SessionTruthTests.)
        #expect(outcome.0 == "Unauthorized. Please call `Sahha.authenticate(...)` first.")
        #expect(outcome.1 == -1)
    }

    @Test("With no configure requested, an authenticated caller proceeds straight to the task")
    func emptyBoxFallsThroughToTheTask() async {
        let session = FakeSessionReader(profileToken: "already-authenticated")
        let box = ConfigurationTaskBox()

        let outcome: (String?, Int) = await withCheckedContinuation { (continuation: CheckedContinuation<(String?, Int), Never>) in
            Sahha.runAsyncWithCallback(
                callback: { continuation.resume(returning: ($0, $1)) },
                requiresAuth: true,
                configurationTaskBox: box,
                session: session,
                actor: SahhaActor(),
                task: { 7 },
                defaultErrorValue: -1
            )
        }

        #expect(outcome.0 == nil)
        #expect(outcome.1 == 7)
    }

    // MARK: - Box semantics

    @Test("A reconfigure supersedes a wedged earlier configure for waiting calls")
    func boxFollowsTheLatestConfigure() async {
        let session = FakeSessionReader()
        let box = ConfigurationTaskBox()
        let gate = DeauthGate()
        // The original configure never resolves (wedged on the gate)…
        box.capture(Task { await gate.waitUntilOpen() })
        // …but a reconfigure lands and authenticates promptly.
        box.capture(Task { session.setProfileToken("reconfigured-token") })

        let outcome: (String?, Int) = await withCheckedContinuation { (continuation: CheckedContinuation<(String?, Int), Never>) in
            Sahha.runAsyncWithCallback(
                callback: { continuation.resume(returning: ($0, $1)) },
                requiresAuth: true,
                configurationTaskBox: box,
                session: session,
                actor: SahhaActor(),
                task: { 5 },
                defaultErrorValue: -1
            )
        }

        #expect(outcome.0 == nil)
        #expect(outcome.1 == 5)

        await gate.open()  // release the wedged stand-in
    }

    @Test("Calls without the auth guard never wait on configuration")
    func nonAuthCallsDoNotAwaitTheBox() async {
        let session = FakeSessionReader()  // signed out — irrelevant without the guard
        let box = ConfigurationTaskBox()
        let gate = DeauthGate()
        box.capture(Task { await gate.waitUntilOpen() })  // configure wedged

        let outcome: (String?, Int) = await withCheckedContinuation { (continuation: CheckedContinuation<(String?, Int), Never>) in
            Sahha.runAsyncWithCallback(
                callback: { continuation.resume(returning: ($0, $1)) },
                requiresAuth: false,
                configurationTaskBox: box,
                session: session,
                actor: SahhaActor(),
                task: { 3 },
                defaultErrorValue: -1
            )
        }

        // Completing while the configure is still wedged pins that only the
        // auth guard acquired the new dependency on configuration.
        #expect(outcome.0 == nil)
        #expect(outcome.1 == 3)

        await gate.open()
    }
}

// MARK: - Helpers

/// Injectable session reader whose token is swapped mid-test — from inside a
/// captured configure task — so it is a lock-boxed class, not a struct.
private final class FakeSessionReader: SessionReading, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    init(profileToken: String? = nil) {
        token = profileToken
    }

    func profileToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    func setProfileToken(_ newToken: String?) {
        lock.lock()
        defer { lock.unlock() }
        token = newToken
    }
}

/// Records `(error, value)` callback invocations so tests can observe "not
/// fired yet" — a continuation can only observe the first fire.
private final class CallbackRecorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [(String?, Value)] = []

    func record(_ error: String?, _ value: Value) {
        lock.lock()
        defer { lock.unlock() }
        outcomes.append((error, value))
    }

    var first: (String?, Value)? {
        lock.lock()
        defer { lock.unlock() }
        return outcomes.first
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return outcomes.count
    }
}

private func waitUntil(timeout: Double = 5, _ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return await condition()
}
