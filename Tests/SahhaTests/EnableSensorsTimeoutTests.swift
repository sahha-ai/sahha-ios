import Testing
import Foundation
import HealthKit
@testable import Sahha

/// Coverage for the fix to the "enableSensors callback never fires" hang: the
/// abandoning-timeout primitive, and HealthKitPermissionsService's serialization +
/// timeout around HKHealthStore.requestAuthorization (which parks forever when the
/// permission sheet cannot be resolved — the failure mode reported in the field).
@Suite("EnableSensorsTimeout")
struct EnableSensorsTimeoutTests {

    // MARK: - withAbandoningTimeout

    @Test("Returns the operation's value when it finishes in time")
    func passesThroughValue() async throws {
        let value = try await withAbandoningTimeout(seconds: 5, operationName: "test") {
            42
        }
        #expect(value == 42)
    }

    @Test("Propagates the operation's own error")
    func passesThroughError() async {
        do {
            try await withAbandoningTimeout(seconds: 5, operationName: "test") {
                throw SahhaError(message: "boom")
            }
            Issue.record("Expected the operation's error to propagate")
        } catch {
            #expect(error.localizedDescription == "boom")
        }
    }

    @Test("Throws AsyncTimeoutError when the operation never completes")
    func timesOutParkedOperation() async {
        let started = Date()
        do {
            try await withAbandoningTimeout(seconds: 0.2, operationName: "parked await") {
                // Simulates requestAuthorization never resuming: park ~forever.
                // (Cancellable, so the abandoned task winds down after the timeout.)
                try? await Task.sleep(nanoseconds: UInt64.max)
            }
            Issue.record("Expected AsyncTimeoutError")
        } catch let error as AsyncTimeoutError {
            #expect(error.operationName == "parked await")
            // The whole point of the fix: we must NOT wait on the parked task.
            #expect(Date().timeIntervalSince(started) < 5)
        } catch {
            Issue.record("Expected AsyncTimeoutError, got \(error)")
        }
    }

    @Test("Late completion after a timeout is a safe no-op")
    func lateCompletionDoesNotDoubleResume() async throws {
        do {
            _ = try await withAbandoningTimeout(seconds: 0.1, operationName: "slow") {
                try? await Task.sleep(nanoseconds: 300_000_000)
                return 1
            }
            Issue.record("Expected AsyncTimeoutError")
        } catch is AsyncTimeoutError {
            // Expected. Now let the abandoned task finish; a double-resume of the
            // continuation would crash the process here.
            try await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    // MARK: - HealthKitPermissionsService

    @Test("requestPermissions throws AsyncTimeoutError instead of hanging when authorization never resolves")
    func requestPermissionsTimesOut() async {
        let store = RecordingHealthStore(autoComplete: false)
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 0.3)

        do {
            try await service.requestPermissions(for: [.heart_rate])
            Issue.record("Expected AsyncTimeoutError")
        } catch let error as AsyncTimeoutError {
            #expect(error.operationName == "HealthKit authorization request")
        } catch {
            Issue.record("Expected AsyncTimeoutError, got \(error)")
        }
    }

    @Test("Concurrent requestPermissions calls are serialized onto the health store")
    func concurrentRequestsAreSerialized() async throws {
        let store = RecordingHealthStore(autoComplete: false)
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 5)

        async let first: Void = service.requestPermissions(for: [.heart_rate])
        // Give the first call time to reach the store before starting the second.
        try await Task.sleep(nanoseconds: 100_000_000)
        async let second: Void = service.requestPermissions(for: [.steps])

        try await Task.sleep(nanoseconds: 200_000_000)
        // First request is parked un-answered; the second must be queued, not issued.
        #expect(store.capturedCompletionCount == 1)

        store.completeNext()
        try await first

        // With the first resolved, the queued second request reaches the store.
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(store.capturedCompletionCount == 2)

        store.completeNext()
        try await second
    }

    @Test("A timed-out request releases the serializer for the next request")
    func timeoutReleasesSerializer() async {
        let store = RecordingHealthStore(autoComplete: false)
        let service = HealthKitPermissionsService(healthStore: store, requestTimeout: 0.2)

        // First call times out (never answered)...
        do {
            try await service.requestPermissions(for: [.heart_rate])
            Issue.record("Expected AsyncTimeoutError")
        } catch {}

        // ...and must not deadlock the second call, which is answered promptly.
        store.autoComplete = true
        do {
            try await service.requestPermissions(for: [.steps])
        } catch {
            Issue.record("Second request should succeed after a timed-out first, got \(error)")
        }
    }
}
