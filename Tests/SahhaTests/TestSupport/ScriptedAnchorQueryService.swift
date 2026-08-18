import Foundation
import HealthKit

@testable import Sahha

/// Scriptable `HealthKitAnchorQueryServiceProtocol` double shared by the
/// coordinator suites. Each call consumes the next step of the script; once the
/// script runs dry every further call returns an empty batch, which is how the
/// coordinators' pagination loops terminate.
final class ScriptedAnchorQueryService: HealthKitAnchorQueryServiceProtocol, @unchecked Sendable {
    enum Step {
        /// Return these samples with this anchor.
        case batch([HKSample], HKQueryAnchor?)
        /// Return this batch on this call and on every call after it — the
        /// endless identical page produced by an anchor that never advances.
        case repeatingBatch([HKSample], HKQueryAnchor?)
        /// Never return, ignoring task cancellation — the worst-case wedged
        /// query whose result handler never fires.
        case parkForever
    }

    private typealias Continuation = CheckedContinuation<([HKSample], HKQueryAnchor?), Never>

    private let lock = NSLock()
    private var script: [Step]
    private var _capturedPredicates: [NSPredicate?] = []
    private var _callCount = 0
    // Parked continuations are retained so the eternal suspension is deliberate
    // rather than a CheckedContinuation leak.
    private var parked: [Continuation] = []

    init(script: [Step]) {
        self.script = script
    }

    /// Batch-list convenience used by the date-cutoff tests.
    convenience init(batches: [([HKSample], HKQueryAnchor?)]) {
        self.init(script: batches.map { .batch($0.0, $0.1) })
    }

    /// The predicate of every call, in order.
    var capturedPredicates: [NSPredicate?] {
        lock.lock()
        defer { lock.unlock() }
        return _capturedPredicates
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    func runAnchorQuery(
        for sampleType: HKSampleType,
        predicate: NSPredicate?,
        anchor: HKQueryAnchor?,
        limit: Int
    ) async throws -> ([HKSample], HKQueryAnchor?) {
        switch nextStep(recording: predicate) {
        case let .batch(samples, anchor)?, let .repeatingBatch(samples, anchor)?:
            return (samples, anchor)
        case .parkForever?:
            return await withCheckedContinuation { park($0) }
        case nil:
            return ([], nil)
        }
    }

    // Locking lives in synchronous helpers: NSLock is unavailable from async
    // contexts.

    private func nextStep(recording predicate: NSPredicate?) -> Step? {
        lock.lock()
        defer { lock.unlock() }
        _capturedPredicates.append(predicate)
        _callCount += 1
        guard let step = script.first else { return nil }
        if case .repeatingBatch = step {} else { script.removeFirst() }
        return step
    }

    private func park(_ continuation: Continuation) {
        lock.lock()
        defer { lock.unlock() }
        parked.append(continuation)
    }
}
