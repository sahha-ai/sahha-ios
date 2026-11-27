import Testing
import Foundation
import HealthKit
import UIKit

@testable import Sahha

// Coverage for the UIKit background task each HealthKit observer update runs
// under, and for HealthKit's completion handler, which ends with it.
//
// The expiration handler used to only log. A run that outlasted the app's
// background time (slow anchored-query pages, or a wait for a query slot) still
// held its background task when the time ran out, and UIKit terminates an app in
// that state. The expiration handler now ends the task and calls the completion
// handler, and the expiry path and the normal path share one claim, so each
// happens exactly once whichever comes first.

// MARK: - Test doubles

/// The ordered record of an update: what the fake provider, the completion
/// handler and the observer handler did.
private final class EventLog: @unchecked Sendable {
    enum Event: Equatable {
        case began(String)
        case ended(Int)
        case completed
        case handlerStarted
        case handlerReturned
    }

    private let lock = NSLock()
    private var _events: [Event] = []

    var events: [Event] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    func record(_ event: Event) {
        lock.lock(); defer { lock.unlock() }
        _events.append(event)
    }
}

/// Stands in for `UIApplication`: hands out sequential identifiers from 1,
/// records begins and ends, and keeps every expiration handler so a test can
/// fire them.
@MainActor
private final class FakeBackgroundTaskProvider: BackgroundTaskProviding {
    private let log: EventLog
    private let grantsTime: Bool
    private let expiresDuringBegin: Bool
    private var nextIdentifier = 1
    private var expirationHandlers: [@MainActor @Sendable () -> Void] = []

    /// - Parameters:
    ///   - grantsTime: false makes `beginBackgroundTask` return `.invalid`, as
    ///     UIKit does when the app cannot run in the background.
    ///   - expiresDuringBegin: fires the expiration handler inside
    ///     `beginBackgroundTask`, before the identifier is returned.
    nonisolated init(log: EventLog, grantsTime: Bool = true, expiresDuringBegin: Bool = false) {
        self.log = log
        self.grantsTime = grantsTime
        self.expiresDuringBegin = expiresDuringBegin
    }

    func beginBackgroundTask(
        withName name: String,
        expirationHandler: @escaping @MainActor @Sendable () -> Void
    ) -> UIBackgroundTaskIdentifier {
        log.record(.began(name))
        guard grantsTime else { return .invalid }
        let identifier = UIBackgroundTaskIdentifier(rawValue: nextIdentifier)
        nextIdentifier += 1
        expirationHandlers.append(expirationHandler)
        if expiresDuringBegin {
            expirationHandler()
        }
        return identifier
    }

    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        log.record(.ended(identifier.rawValue))
    }

    /// Fires every expiration handler, as UIKit does when background time runs out.
    func expire() {
        for handler in expirationHandlers {
            handler()
        }
    }
}

/// A one-shot signal: `wait()` returns once `open()` has been called.
private actor Latch {
    private(set) var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters.removeAll()
    }
}

/// Polls `condition` until it holds or `timeout` elapses; returns the final result.
/// Tests wait for a handler to start with this rather than `Latch.wait()`, so a
/// handler that never runs fails the test instead of hanging the run.
private func waitUntil(timeout: Double = 5, _ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return await condition()
}

/// An observer handler that records its start and its return around `body`.
private func recordingHandler(
    _ log: EventLog,
    body: @escaping @Sendable () async -> Void = {}
) -> HealthKitObserverHandler {
    { _, _ in
        log.record(.handlerStarted)
        await body()
        log.record(.handlerReturned)
    }
}

// MARK: - Tests

@Suite("Observer update background task")
struct ObserverBackgroundTaskTests {
    private let taskName = "Sahha.HealthKit.steps"

    private func makeService(
        _ provider: FakeBackgroundTaskProvider,
        circuitBreaker: CircuitBreaker? = nil
    ) -> HealthKitObserverService {
        HealthKitObserverService(
            healthStore: RecordingHealthStore(),
            observerStore: HealthKitObserverStore(),
            circuitBreaker: circuitBreaker,
            backgroundTasks: provider,
            logger: NoopErrorLogger()
        )
    }

    @Test("A finished run calls the completion handler, then ends the task; a late expiry changes nothing")
    func finishedRunCompletesThenEnds() async throws {
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log)
        let service = makeService(provider)

        await service.handleUpdate(
            for: .steps,
            sampleType: try #require(SahhaSensor.steps.hkSampleType),
            completion: { log.record(.completed) },
            handler: recordingHandler(log)
        )

        // HealthKit hears back before the task ends and lets the app suspend.
        let finished: [EventLog.Event] = [.began(taskName), .handlerStarted, .handlerReturned, .completed, .ended(1)]
        #expect(log.events == finished)

        await provider.expire()
        #expect(log.events == finished)
    }

    @Test("Expiry mid-run completes and ends the task before the expiration handler returns; the finished run does neither again")
    func expiryMidRunEndsOnce() async throws {
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log)
        let service = makeService(provider)
        let sampleType = try #require(SahhaSensor.steps.hkSampleType)
        let started = Latch()
        let release = Latch()

        let update = Task {
            await service.handleUpdate(
                for: .steps,
                sampleType: sampleType,
                completion: { log.record(.completed) },
                handler: recordingHandler(log) {
                    await started.open()
                    await release.wait()
                }
            )
        }
        try #require(await waitUntil { await started.isOpen }, "The observer handler never started")

        // UIKit calls the expiration handler synchronously on the main thread and
        // terminates the app if the task is still held when time runs out, so the
        // task must be ended by the time the handler returns.
        await provider.expire()
        #expect(log.events == [.began(taskName), .handlerStarted, .completed, .ended(1)])

        await release.open()
        await update.value
        #expect(log.events == [.began(taskName), .handlerStarted, .completed, .ended(1), .handlerReturned])
    }

    @Test("Expiry ends every in-flight update's task, each once")
    func expiryEndsEveryInFlightUpdate() async throws {
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log)
        let service = makeService(provider)
        let release = Latch()

        var updates: [Task<Void, Never>] = []
        for sensor in [SahhaSensor.steps, .heart_rate] {
            let sampleType = try #require(sensor.hkSampleType)
            let started = Latch()
            updates.append(Task {
                await service.handleUpdate(
                    for: sensor,
                    sampleType: sampleType,
                    completion: { log.record(.completed) },
                    handler: recordingHandler(log) {
                        await started.open()
                        await release.wait()
                    }
                )
            })
            try #require(await waitUntil { await started.isOpen }, "An observer handler never started")
        }

        await provider.expire()
        // Each expiration handler completed and ended its own update while both
        // runs were still parked.
        let atExpiry = log.events
        #expect(atExpiry.filter { $0 == .completed }.count == 2)
        #expect(atExpiry.filter { $0 == .ended(1) || $0 == .ended(2) } == [.ended(1), .ended(2)])

        await release.open()
        for update in updates {
            await update.value
        }
        // The finished runs added only their handlers' returns.
        #expect(log.events == atExpiry + [.handlerReturned, .handlerReturned])
    }

    @Test("An expiry inside beginBackgroundTask ends the task once its identifier exists, exactly once")
    func expiryDuringBeginEndsOnce() async throws {
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log, expiresDuringBegin: true)
        let service = makeService(provider)

        await service.handleUpdate(
            for: .steps,
            sampleType: try #require(SahhaSensor.steps.hkSampleType),
            completion: { log.record(.completed) },
            handler: recordingHandler(log)
        )

        // The run still goes ahead, as it does when no background time is granted.
        #expect(log.events == [.began(taskName), .completed, .ended(1), .handlerStarted, .handlerReturned])
    }

    @Test("With no background time granted the run still completes, and there is no task to end")
    func noBackgroundTimeStillCompletes() async throws {
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log, grantsTime: false)
        let service = makeService(provider)

        await service.handleUpdate(
            for: .steps,
            sampleType: try #require(SahhaSensor.steps.hkSampleType),
            completion: { log.record(.completed) },
            handler: recordingHandler(log)
        )

        #expect(log.events == [.began(taskName), .handlerStarted, .handlerReturned, .completed])
    }

    @Test("An open circuit skips the handler but still completes and ends the task once")
    func openCircuitCompletesAndEnds() async throws {
        let log = EventLog()
        let provider = FakeBackgroundTaskProvider(log: log)
        let breaker = CircuitBreaker(failureThreshold: 1)
        await breaker.recordFailure()
        try #require(await breaker.isOpen())
        let service = makeService(provider, circuitBreaker: breaker)

        await service.handleUpdate(
            for: .steps,
            sampleType: try #require(SahhaSensor.steps.hkSampleType),
            completion: { log.record(.completed) },
            handler: recordingHandler(log)
        )

        #expect(log.events == [.began(taskName), .completed, .ended(1)])
    }
}
