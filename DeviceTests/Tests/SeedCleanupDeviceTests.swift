import Foundation
import Testing
@testable import Sahha

/// Removes every step sample this app has written, for when a run stopped before its own
/// clean-up (or ran with SAHHA_KEEP_SEEDED=1). Only runs when asked for:
///
///     TEST_RUNNER_SAHHA_CLEANUP=1 DeviceTests/run.sh <udid> SeedCleanupDeviceTests
@Suite(
    "Seeded-sample clean-up",
    .serialized,
    .enabled(if: DeviceTestEnv.string("SAHHA_CLEANUP") == "1", "Pass TEST_RUNNER_SAHHA_CLEANUP=1 to run")
)
struct SeedCleanupDeviceTests {
    private let health = DeviceHealthStore.shared

    /// Whether HealthKit answers at all: one sample, no predicate (milliseconds when idle).
    /// Times out while a long delete is still running inside HealthKit.
    @Test("HealthKit answers a one-sample query", .timeLimit(.minutes(1)))
    func probeHealthKitResponsiveness() async throws {
        try await health.authorize()
        let started = Date()
        let (samples, _) = try await HealthKitAnchorQueryService(healthStore: health.store)
            .runAnchorQuery(for: health.steps, predicate: nil, anchor: nil, limit: 1)
        DeviceTestReport.record("healthkit-probe", [
            "samples": samples.count,
            "seconds": DeviceTestReport.seconds(Date().timeIntervalSince(started)),
        ])
    }

    /// Counts what is left, and fails fast if HealthKit does not answer: a delete still
    /// running inside HealthKit holds every later query behind it.
    @Test("Counts the samples this app wrote", .timeLimit(.minutes(1)))
    func reportSeededSampleCount() async throws {
        try await health.authorize()
        let started = Date()
        let count = try await health.seededSampleCount()
        DeviceTestReport.record("seed-count", [
            "seededSamples": count,
            "seconds": DeviceTestReport.seconds(Date().timeIntervalSince(started)),
        ])
    }

    @Test("Every sample this app wrote is deleted", .timeLimit(.minutes(120)))
    func deleteEverySeededSample() async throws {
        try await health.authorize()

        print("[SeedCleanup] counting")
        let before = try await health.seededSampleCount()
        print("[SeedCleanup] \(before) to delete")
        let started = Date()
        let deleted = try await health.deleteSeeded { soFar in
            print("[SeedCleanup] deleted \(soFar) of about \(before)")
        }
        let remaining = try await health.seededSampleCount()

        DeviceTestReport.record("seed-cleanup", [
            "samplesBefore": before,
            "deleted": deleted,
            "remaining": remaining,
            "seconds": DeviceTestReport.seconds(Date().timeIntervalSince(started)),
        ])
        #expect(remaining == 0)
    }
}
