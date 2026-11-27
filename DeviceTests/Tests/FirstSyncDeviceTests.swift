import Foundation
import HealthKit
import Testing
@testable import Sahha

/// A first sync (no anchor) on a phone with a large step history, through the SDK's real
/// pager and real HealthKit.
///
/// Why: a 1.4.0 field report showed a first-sync steps page missing the 30s timeout, and
/// the simulator load test found the cause. With no anchor and the 30-day predicate, the
/// first page scans every older sample of the type before it reaches the window, so its
/// cost grows with the whole history, not the page size. A simulator on a Mac is far
/// faster than a phone, so only a phone can say how close a real history gets to 30s.
///
/// The seeded history ends a day before the 30-day window. The SDK drops samples older
/// than the window on every sync, so other Sahha apps on the phone never upload them,
/// and the scan cost being measured is exactly what they add. Every seeded sample comes
/// from this app's own HealthKit source and is deleted at the end of the run (unless
/// SAHHA_KEEP_SEEDED=1); no other app's data is touched.
@Suite("First sync on a large HealthKit history", .serialized)
struct FirstSyncDeviceTests {
    private let health = DeviceHealthStore.shared

    // Long enough for the clean-up after a five-year seed: a month-at-a-time delete of
    // 1.75M samples, which is slow on a phone.
    @Test("A first sync pages through the 30-day window without a page timing out", .timeLimit(.minutes(120)))
    func firstSyncCompletesWithinTheTimeout() async throws {
        try await health.authorize()

        let now = Date()
        let windowStart = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let seedEnd = windowStart.addingTimeInterval(-86_400)
        let days = DeviceTestEnv.seedDays
        let perDay = DeviceTestEnv.seedSamplesPerDay

        // SAHHA_REUSE_SEEDED=1 measures the history already on the phone, so a seed kept
        // with SAHHA_KEEP_SEEDED=1 can be measured cold, right after a reboot.
        let reuse = DeviceTestEnv.string("SAHHA_REUSE_SEEDED") == "1"
        var removedBefore = 0
        var seeded = 0
        var seedSeconds: TimeInterval = 0
        if !reuse {
            removedBefore = try await health.deleteSeeded()
            let seedStarted = Date()
            seeded = try await health.seedStepHistory(days: days, samplesPerDay: perDay, endingAt: seedEnd)
            seedSeconds = Date().timeIntervalSince(seedStarted)
        }

        do {
            let run = try await runFirstSync(windowStart: windowStart, now: now)

            // A reused seed is counted only after the timed sync. The count reads every
            // seeded sample, so counting first would warm the very history this mode
            // measures cold.
            if reuse {
                seeded = try await health.seededSampleCount()
                try #require(seeded > 0, "SAHHA_REUSE_SEEDED=1, but this app has no seeded samples on the phone. Seed first with SAHHA_KEEP_SEEDED=1.")
            }

            // For the predicate-free first sync that is still on the table: the same
            // first page with no date predicate, which the simulator found fast.
            let unpredicated = try await timeFirstPage(predicate: nil)

            DeviceTestReport.record(reuse ? "first-sync-reused" : "first-sync", [
                "reusedExistingSeed": reuse,
                "seededSamples": seeded,
                // Unknown for a reused seed: only its sample count can be read back.
                "seededDays": reuse ? NSNull() : days,
                "seededPerDay": reuse ? NSNull() : perDay,
                "seedSeconds": DeviceTestReport.seconds(seedSeconds),
                "staleSeedRemovedFirst": removedBefore,
                "pages": run.pageSeconds.count,
                "samplesInWindow": run.samples,
                "firstPageSeconds": DeviceTestReport.seconds(run.pageSeconds.first ?? 0),
                "slowestPageSeconds": DeviceTestReport.seconds(run.pageSeconds.max() ?? 0),
                "totalSeconds": DeviceTestReport.seconds(run.pageSeconds.reduce(0, +)),
                "firstPageWithoutPredicateSeconds": DeviceTestReport.seconds(unpredicated),
                "timeoutSeconds": 30,
            ])

            if !reuse {
                #expect(seeded == days * perDay)
            }
            // The pager throws AnchoredQueryTimeoutError for a page past 30s, so reaching
            // here means none did. The margin check flags a phone getting close.
            #expect((run.pageSeconds.max() ?? 0) < 15, "A page took over half the 30s budget: a slower phone or a longer history would time out.")
        } catch {
            try await cleanUp()
            throw error
        }
        try await cleanUp()
    }

    // MARK: - Helpers

    private struct FirstSyncRun {
        var pageSeconds: [TimeInterval] = []
        var samples = 0
    }

    /// The data-log coordinator's first-sync loop: no anchor, the 30-day predicate, pages
    /// of up to 500 through the shared pager until an empty page.
    private func runFirstSync(windowStart: Date, now: Date) async throws -> FirstSyncRun {
        let pager = AnchoredQueryPager(
            logLabel: "DeviceTest",
            service: HealthKitAnchorQueryService(healthStore: health.store),
            slots: AsyncSemaphore(value: AnchoredQueryPager.defaultConcurrencyLimit),
            fullPageSize: 500,
            timeout: 30,
            appStateProvider: nil
        )
        var run = FirstSyncRun()
        var anchor: HKQueryAnchor?
        while true {
            let started = Date()
            let (samples, newAnchor) = try await pager.fetchPage(
                for: .steps,
                sampleType: health.steps,
                startDate: windowStart,
                endDate: now,
                anchor: anchor,
                pagesCompleted: run.pageSeconds.count
            )
            run.pageSeconds.append(Date().timeIntervalSince(started))
            guard !samples.isEmpty else { break }
            run.samples += samples.count
            anchor = newAnchor
        }
        return run
    }

    private func timeFirstPage(predicate: NSPredicate?) async throws -> TimeInterval {
        let started = Date()
        _ = try await HealthKitAnchorQueryService(healthStore: health.store)
            .runAnchorQuery(for: health.steps, predicate: predicate, anchor: nil, limit: 500)
        return Date().timeIntervalSince(started)
    }

    private func cleanUp() async throws {
        guard !DeviceTestEnv.keepSeeded else { return }
        try await health.deleteSeeded()
        let remaining = try await health.seededSampleCount()
        #expect(remaining == 0, "\(remaining) seeded samples are still on the phone. Run SeedCleanupDeviceTests.")
    }
}
