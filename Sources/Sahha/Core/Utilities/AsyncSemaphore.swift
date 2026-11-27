/// Counting semaphore for async code. `wait()` takes a permit, suspending until one
/// is free; `signal()` returns it, handing it straight to the oldest waiter so a
/// newcomer can never overtake the queue.
final actor AsyncSemaphore {
    /// How busy the semaphore is: permits taken, callers queued for one, and the total.
    struct Load: Sendable, Equatable {
        let inUse: Int
        let waiting: Int
        let capacity: Int
    }

    private enum Waiter {
        case uncancellable(CheckedContinuation<Void, Never>)
        case cancellable(id: UInt64, CheckedContinuation<Void, Error>)
    }

    private var value: Int
    private let maxValue: Int
    private var waiters: [Waiter] = []
    private var nextWaiterId: UInt64 = 0

    init(value: Int) {
        self.value = max(0, value)
        self.maxValue = max(0, value)
    }

    var load: Load {
        Load(inUse: maxValue - value, waiting: waiters.count, capacity: maxValue)
    }

    func wait() async {
        if value > 0 {
            value -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(.uncancellable(continuation))
            }
        }
    }

    /// Like `wait()`, except that a caller whose task is cancelled, before or while it
    /// is queued, throws `CancellationError` instead of taking a permit, and leaves the
    /// queue. Only a caller that returns normally holds a permit to `signal()`.
    func cancellableWait() async throws {
        try Task.checkCancellation()
        if value > 0 {
            value -= 1
            return
        }
        let id = nextWaiterId
        nextWaiterId &+= 1
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(.cancellable(id: id, continuation))
            }
        } onCancel: {
            // Runs off the actor, possibly before the waiter is queued. The hop lands
            // after this call has queued it, since the actor is busy until then.
            Task { await self.removeCancelledWaiter(id) }
        }
    }

    func signal() {
        if !waiters.isEmpty {
            switch waiters.removeFirst() {
            case let .uncancellable(continuation):
                continuation.resume()
            case let .cancellable(_, continuation):
                continuation.resume()
            }
        } else if value < maxValue {
            value += 1
        }
    }

    func waitForAll() async {
        while !waiters.isEmpty || value < maxValue {
            await wait()
        }
    }

    private func removeCancelledWaiter(_ id: UInt64) {
        let index = waiters.firstIndex {
            if case let .cancellable(waiterId, _) = $0 { return waiterId == id }
            return false
        }
        // No match means `signal()` already handed this caller a permit, which it now
        // owns and must return.
        guard let index, case let .cancellable(_, continuation) = waiters.remove(at: index) else {
            return
        }
        continuation.resume(throwing: CancellationError())
    }
}
