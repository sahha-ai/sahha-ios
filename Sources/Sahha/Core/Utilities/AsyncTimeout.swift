import Foundation

/// Error thrown when an async operation exceeds its allotted time.
struct AsyncTimeoutError: LocalizedError {
    let seconds: TimeInterval
    let operationName: String

    var errorDescription: String? {
        "\(operationName) timed out after \(Int(seconds))s."
    }
}

/// Runs `operation` and throws `AsyncTimeoutError` if it does not finish within
/// `seconds`.
///
/// Unlike a `withThrowingTaskGroup` race, this helper does NOT wait for the losing
/// task: a task group always awaits all of its children before returning, so racing
/// a non-cancellation-responsive await (such as `HKHealthStore.requestAuthorization`,
/// which stays suspended until the user dismisses the permission sheet) inside a
/// group would still hang. Here the operation runs in an unstructured task that is
/// cancelled on timeout and then abandoned — if it can't honor cancellation it keeps
/// running in the background, and whichever side finishes second finds the
/// continuation already claimed and becomes a no-op.
///
/// Because the work task is unstructured, the caller's own cancellation would not
/// reach the operation on its own; it is forwarded explicitly. A
/// cancellation-responsive operation then throws `CancellationError` through the
/// gate, and an unresponsive one is still bounded by the timeout.
func withAbandoningTimeout<T: Sendable>(
    seconds: TimeInterval,
    operationName: String,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let gate = ResumeOnceGate()
    let relay = CancellationRelay()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            let workTask = Task {
                do {
                    let value = try await operation()
                    if gate.claim() { continuation.resume(returning: value) }
                } catch {
                    if gate.claim() { continuation.resume(throwing: error) }
                }
            }
            relay.register(workTask)
            Task {
                try? await Task.sleep(nanoseconds: UInt64(max(seconds, 0.1) * 1_000_000_000))
                if gate.claim() {
                    workTask.cancel()
                    continuation.resume(throwing: AsyncTimeoutError(seconds: seconds, operationName: operationName))
                }
            }
        }
    } onCancel: {
        relay.cancel()
    }
}

/// Relays the caller's cancellation to the unstructured work task, whichever of
/// registration and cancellation happens first.
private final class CancellationRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var cancelled = false

    func register(_ task: Task<Void, Never>) {
        lock.lock()
        self.task = task
        let alreadyCancelled = cancelled
        lock.unlock()
        if alreadyCancelled { task.cancel() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let task = task
        lock.unlock()
        task?.cancel()
    }
}

/// Thread-safe single-claim flag ensuring the continuation above is resumed exactly once.
private final class ResumeOnceGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    /// Returns true for exactly one caller; false for every caller after that.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
