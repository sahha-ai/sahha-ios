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
/// Unlike a `withThrowingTaskGroup` race (see `runAnchorQueryWithTimeout`), this
/// helper does NOT wait for the losing task: a task group always awaits all of its
/// children before returning, so racing a non-cancellation-responsive await (such as
/// `HKHealthStore.requestAuthorization`, which stays suspended until the user
/// dismisses the permission sheet) inside a group would still hang. Here the
/// operation runs in an unstructured task that is cancelled on timeout and then
/// abandoned — if it can't honor cancellation it keeps running in the background,
/// and whichever side finishes second finds the continuation already claimed and
/// becomes a no-op.
func withAbandoningTimeout<T: Sendable>(
    seconds: TimeInterval,
    operationName: String,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let gate = ResumeOnceGate()
    return try await withCheckedThrowingContinuation { continuation in
        let workTask = Task {
            do {
                let value = try await operation()
                if gate.claim() { continuation.resume(returning: value) }
            } catch {
                if gate.claim() { continuation.resume(throwing: error) }
            }
        }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(max(seconds, 0.1) * 1_000_000_000))
            if gate.claim() {
                workTask.cancel()
                continuation.resume(throwing: AsyncTimeoutError(seconds: seconds, operationName: operationName))
            }
        }
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
