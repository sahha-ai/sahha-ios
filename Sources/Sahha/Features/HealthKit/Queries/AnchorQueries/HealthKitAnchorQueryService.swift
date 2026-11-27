import HealthKit

final class HealthKitAnchorQueryService: HealthKitAnchorQueryServiceProtocol {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }

    func runAnchorQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        anchor: HKQueryAnchor?,
        limit: Int
    ) async throws -> AnchoredQueryPage {
        // The query object is created inside the continuation closure but must be
        // reachable from the cancellation handler, so the two sides rendezvous on a
        // lock-protected lifecycle box that arbitrates which of them resumes.
        let lifecycle = AnchorQueryLifecycle()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: sampleType,
                    predicate: predicate,
                    anchor: anchor,
                    limit: limit
                ) { _, samplesOrNil, deletedOrNil, newAnchor, errorOrNil in
                    guard let continuation = lifecycle.claimForResult() else { return }
                    if let error = errorOrNil {
                        continuation.resume(throwing: error)
                    } else {
                        // The deletions count toward the page limit, so the callers
                        // need their number to tell a deletion-only page from the end.
                        continuation.resume(returning: AnchoredQueryPage(
                            samples: samplesOrNil ?? [],
                            deletedObjectCount: deletedOrNil?.count ?? 0,
                            anchor: newAnchor
                        ))
                    }
                }
                if lifecycle.register(query, continuation: continuation) {
                    healthStore.execute(query)
                } else {
                    // Cancellation won before the query could start.
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            // `HKHealthStore.stop` never fires the query's result handler, so the
            // parked continuation must be resumed here as well — otherwise it, and
            // the task awaiting it, would stay suspended forever.
            guard let (query, continuation) = lifecycle.claimForCancel() else { return }
            healthStore.stop(query)
            continuation.resume(throwing: CancellationError())
        }
    }
}

/// Single-claim arbiter between an anchored query's result handler and task
/// cancellation: whichever side claims first resumes the continuation, and the
/// loser becomes a no-op.
private final class AnchorQueryLifecycle: @unchecked Sendable {
    typealias Continuation = CheckedContinuation<AnchoredQueryPage, Error>

    private let lock = NSLock()
    private var query: HKAnchoredObjectQuery?
    private var continuation: Continuation?
    private var finished = false
    private var cancelled = false

    /// Returns true if the query should be executed; false if cancellation already
    /// won, in which case the caller must resume the continuation itself.
    func register(_ query: HKAnchoredObjectQuery, continuation: Continuation) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if cancelled {
            finished = true
            return false
        }
        self.query = query
        self.continuation = continuation
        return true
    }

    func claimForResult() -> Continuation? {
        lock.lock()
        defer { lock.unlock() }
        guard !finished, let continuation else { return nil }
        finished = true
        clear()
        return continuation
    }

    func claimForCancel() -> (HKAnchoredObjectQuery, Continuation)? {
        lock.lock()
        defer { lock.unlock() }
        cancelled = true
        guard !finished, let query, let continuation else { return nil }
        finished = true
        clear()
        return (query, continuation)
    }

    private func clear() {
        query = nil
        continuation = nil
    }
}
