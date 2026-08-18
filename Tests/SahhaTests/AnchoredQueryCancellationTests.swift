import Testing
import Foundation
import HealthKit

@testable import Sahha

/// Coverage for cooperative cancellation in `HealthKitAnchorQueryService`.
/// Stopping the underlying HealthKit query is not enough on its own —
/// `HKHealthStore.stop` never fires the query's result handler, so cancellation
/// must also resume the parked continuation, exactly once, or the awaiting task
/// stays suspended forever.
@Suite("AnchoredQueryCancellation")
struct AnchoredQueryCancellationTests {

    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

    private func waitUntil(timeout: Double = 5, _ condition: @Sendable () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    @Test("Cancelling a parked query stops the HealthKit query exactly once and throws CancellationError")
    func cancelStopsQueryAndResumesContinuation() async {
        let store = RecordingHealthStore()
        let service = HealthKitAnchorQueryService(healthStore: store)
        let type = heartRateType

        let task = Task {
            try await service.runAnchorQuery(for: type, predicate: nil, anchor: nil, limit: 10)
        }

        // The recording store never fires result handlers, so the query parks.
        #expect(await waitUntil { store.executedQueries.count == 1 })

        task.cancel()

        switch await task.result {
        case .success:
            Issue.record("Expected CancellationError, got a result")
        case let .failure(error):
            #expect(error is CancellationError)
        }
        #expect(store.stoppedQueries.count == 1)
        #expect(store.stoppedQueries.first === store.executedQueries.first)
    }

    @Test("A task cancelled before the query starts neither executes nor stops anything")
    func preCancelledTaskNeverExecutes() async {
        let store = RecordingHealthStore()
        let service = HealthKitAnchorQueryService(healthStore: store)
        let type = heartRateType

        let task = Task { () throws -> ([HKSample], HKQueryAnchor?) in
            // Hold until cancellation is definitely delivered, then call.
            while !Task.isCancelled { await Task.yield() }
            return try await service.runAnchorQuery(for: type, predicate: nil, anchor: nil, limit: 10)
        }
        task.cancel()

        switch await task.result {
        case .success:
            Issue.record("Expected CancellationError, got a result")
        case let .failure(error):
            #expect(error is CancellationError)
        }
        #expect(store.executedQueries.isEmpty)
        #expect(store.stoppedQueries.isEmpty)
    }
}
