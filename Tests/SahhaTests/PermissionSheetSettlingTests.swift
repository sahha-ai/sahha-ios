import Testing
import Foundation
import HealthKit
import UIKit
@testable import Sahha

/// Coverage for back-to-back permission requests on iOS 27. HealthKit calls a request's
/// completion while its sheet is still animating away; a request issued in that window
/// is presented on the dismissing sheet, which UIKit refuses, so no sheet appears and the
/// completion never comes. HealthKitPermissionsService now holds each request, and the
/// caller, until the screen has settled.
///
/// The screen is a scripted flag read through the real PermissionSheetSettler, so these
/// tests drive the same polling loop the SDK runs, with RecordingHealthStore standing in
/// for HealthKit.
@Suite("PermissionSheetSettling")
struct PermissionSheetSettlingTests {

    // MARK: - HealthKitPermissionsService ordering

    @Test("A queued request reaches HealthKit only after the previous sheet has gone")
    func queuedRequestWaitsForPreviousSheetToGo() async throws {
        let screen = ScriptedScreen()
        let store = RecordingHealthStore(autoComplete: false)
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 10, sheetSettler: screen.settler())

        let first = Task { try await service.requestPermissions(for: [.weight]) }
        #expect(await waitUntil { store.capturedCompletionCount == 1 })

        // HealthKit's order on iOS 27: the sheet starts to dismiss, then the completion fires.
        screen.isSettled = false
        store.completeNext()
        let second = Task { try await service.requestPermissions(for: [.height]) }

        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(store.capturedCompletionCount == 1, "The second request was issued while the first sheet was still on screen")

        screen.isSettled = true
        try await first.value
        #expect(await waitUntil { store.capturedCompletionCount == 2 })
        store.completeNext()
        try await second.value

        #expect(store.authorizationRequests == [
            Set(SahhaSensor.weight.hkPermissions),
            Set(SahhaSensor.height.hkPermissions),
        ])
    }

    @Test("requestPermissions returns only once its sheet has gone")
    func returnsAfterSheetHasGone() async throws {
        let screen = ScriptedScreen()
        let store = RecordingHealthStore(autoComplete: false)
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 10, sheetSettler: screen.settler())
        let returned = Flag()

        let request = Task {
            try await service.requestPermissions(for: [.weight])
            returned.set()
        }
        #expect(await waitUntil { store.capturedCompletionCount == 1 })

        screen.isSettled = false
        store.completeNext()
        try await Task.sleep(nanoseconds: 300_000_000)
        // A host app that presents its own UI on return would hit the same refusal.
        #expect(!returned.isSet, "Returned while the sheet was still dismissing")

        screen.isSettled = true
        try await request.value
        #expect(returned.isSet)
    }

    @Test("A request waits for a presentation already in progress before asking HealthKit")
    func waitsForBusyScreenBeforeAsking() async throws {
        let screen = ScriptedScreen()
        screen.isSettled = false
        let store = RecordingHealthStore(autoComplete: true)
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 10, sheetSettler: screen.settler())

        let request = Task { try await service.requestPermissions(for: [.weight]) }
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(store.capturedCompletionCount == 0, "Asked HealthKit while the screen was mid-transition")

        screen.isSettled = true
        try await request.value
        #expect(store.capturedCompletionCount == 1)
    }

    @Test("A screen that never settles delays requests by the cap, never blocks them")
    func unsettledScreenIsBounded() async throws {
        let screen = ScriptedScreen()
        screen.isSettled = false
        let store = RecordingHealthStore(autoComplete: true)
        let service = HealthKitPermissionsService(
            healthStore: store,
            requestTimeout: 10,
            sheetSettler: screen.settler(timeout: 0.2)
        )

        let started = Date()
        try await service.requestPermissions(for: [.weight])
        try await service.requestPermissions(for: [.height])

        #expect(store.capturedCompletionCount == 2)
        // Two settles per request, each capped at 0.2s.
        #expect(Date().timeIntervalSince(started) < 3)
    }

    @Test("A failed request still waits for its sheet to go, then releases the next request")
    func failedRequestWaitsAndReleases() async throws {
        let screen = ScriptedScreen()
        let store = RecordingHealthStore(autoComplete: false)
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 10, sheetSettler: screen.settler())

        let first = Task { try await service.requestPermissions(for: [.weight]) }
        #expect(await waitUntil { store.capturedCompletionCount == 1 })
        screen.isSettled = false
        store.completeNext(success: false, error: NSError(domain: "HKErrorDomain", code: 5))

        let second = Task { try await service.requestPermissions(for: [.height]) }
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(store.capturedCompletionCount == 1)

        screen.isSettled = true
        await #expect(throws: (any Error).self) { try await first.value }
        #expect(await waitUntil { store.capturedCompletionCount == 2 })
        store.completeNext()
        try await second.value
    }

    @Test("A screen that is already settled adds no wait")
    func settledScreenAddsNoWait() async throws {
        let screen = ScriptedScreen()
        let store = RecordingHealthStore(autoComplete: true)
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 10, sheetSettler: screen.settler())

        let started = Date()
        for _ in 0..<5 {
            try await service.requestPermissions(for: [.weight])
        }
        #expect(store.capturedCompletionCount == 5)
        #expect(Date().timeIntervalSince(started) < 1)
        // Checked before and after each request, and settled first time every time.
        #expect(screen.checkCount == 10)
    }

    // MARK: - PermissionSheetSettler

    @Test("waitUntilSettled reports whether the screen settled before the cap")
    func waitReportsOutcome() async {
        let screen = ScriptedScreen()
        #expect(await screen.settler().waitUntilSettled())

        screen.isSettled = false
        #expect(await screen.settler(timeout: 0.1).waitUntilSettled() == false)
    }

    @Test("waitUntilSettled stops waiting when its task is cancelled")
    func waitStopsOnCancellation() async {
        let screen = ScriptedScreen()
        screen.isSettled = false
        let settler = screen.settler(timeout: 30)
        let wait = Task { await settler.waitUntilSettled() }
        try? await Task.sleep(nanoseconds: 100_000_000)

        let started = Date()
        wait.cancel()
        #expect(await wait.value == false)
        #expect(Date().timeIntervalSince(started) < 2)
    }

    @Test("Settled means nothing mid-transition and no Health sheet in any window")
    func settledRule() {
        typealias Link = PermissionSheetSettler.Link
        let plain = Link(isTransitioning: false, isHealthPermissionSheet: false)
        let moving = Link(isTransitioning: true, isHealthPermissionSheet: false)
        let healthSheet = Link(isTransitioning: false, isHealthPermissionSheet: true)
        let dismissingHealthSheet = Link(isTransitioning: true, isHealthPermissionSheet: true)

        #expect(PermissionSheetSettler.isSettled([]))
        #expect(PermissionSheetSettler.isSettled([[plain], [plain, plain]]))
        // The iOS 27 case: HealthKit has called back, its sheet is still dismissing.
        #expect(!PermissionSheetSettler.isSettled([[plain, dismissingHealthSheet]]))
        // HealthKit called back before its sheet started to dismiss.
        #expect(!PermissionSheetSettler.isSettled([[plain, healthSheet]]))
        // The host app's own modal still animating, in another window.
        #expect(!PermissionSheetSettler.isSettled([[plain], [plain, moving]]))
    }

    @Test("Recognises HealthKit's sheet by its class, and nothing else")
    @MainActor
    func recognisesHealthSheet() {
        #expect(!PermissionSheetSettler.isHealthPermissionSheet(UIViewController()))
        #expect(!PermissionSheetSettler.isHealthPermissionSheet(UINavigationController()))
        #expect(PermissionSheetSettler.isHealthPermissionSheet(FakeHealthPrivacySheet()))
    }

    @Test("Reading the real screen is safe here and finds nothing in flight")
    @MainActor
    func readsRealScreen() {
        // Hostless test runs have no UIApplication; hosted ones have an idle window.
        // Either way the read must not crash and must report settled.
        #expect(PermissionSheetSettler.isSettled(PermissionSheetSettler.currentChains()))
    }
}

// MARK: - Doubles

/// Named like HealthKit's private sheet class, which tests cannot instantiate.
@objc(HKHealthPrivacyFakeSheetViewController)
private final class FakeHealthPrivacySheet: UIViewController {}

/// The screen as the settler sees it: settled or not, scripted by the test.
private final class ScriptedScreen: @unchecked Sendable {
    private let lock = NSLock()
    private var settled = true
    private var checks = 0

    var isSettled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return settled }
        set { lock.lock(); defer { lock.unlock() }; settled = newValue }
    }

    /// How many times a settler has looked.
    var checkCount: Int {
        lock.lock(); defer { lock.unlock() }
        return checks
    }

    private func check() -> Bool {
        lock.lock(); defer { lock.unlock() }
        checks += 1
        return settled
    }

    /// The real settler, polling this screen instead of UIKit.
    func settler(timeout: TimeInterval = 10) -> PermissionSheetSettler {
        PermissionSheetSettler(timeout: timeout, pollInterval: 0.01) { [self] in check() }
    }
}

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock(); defer { lock.unlock() }
        value = true
    }
}

private func waitUntil(timeout: Double = 5, _ condition: @Sendable () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}
