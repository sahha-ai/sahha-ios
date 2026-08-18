import Foundation

/// Pure retry-scheduling state machine for the deferred authenticated bring-up
/// (PRD #76 D10). The coordinator feeds it triggers and outcomes with explicit
/// timestamps; the policy owns every scheduling decision — the backoff window,
/// jitter, the inter-attempt floor, the attempt budget, the one-shot window
/// bypass, and the completed latch — and performs none of the work, so it is
/// testable without clocks, timers, or doubles.
///
/// There are deliberately no timers anywhere: an attempt only ever runs when an
/// external trigger (lifecycle event, unlock, network transition) is admitted
/// through `admitTrigger(at:)`.
struct BringUpRetryPolicy: Sendable {
    enum State: Sendable, Equatable {
        /// No deferred bring-up outstanding: a fresh machine, or one stood down
        /// by a verdict no retry can change.
        case dormant
        /// A deferral is outstanding: triggers may be admitted as windows open.
        case armed
        /// Bring-up succeeded. Latched: nothing is admitted again for the
        /// machine's lifetime (every configure installs a fresh machine).
        case completed
    }

    /// First backoff window, seconds.
    static let initialDelay: TimeInterval = 30
    /// Backoff ceiling, seconds.
    static let maxDelay: TimeInterval = .minutes(15)
    /// Jitter spread: every window is scaled by a factor in [0.75, 1.25].
    static let jitterSpread: Double = 0.25
    /// Hard minimum between admitted attempts, bypass or not — collapses a
    /// trigger burst (resume and foreground fire back to back) into one attempt.
    static let interAttemptFloor: TimeInterval = 5
    /// Attempt budget per machine (i.e. per configure); a network transition
    /// grants a fresh budget.
    static let maxAttempts = 8

    private(set) var state: State = .dormant
    private(set) var attemptCount = 0
    private(set) var lastAttemptAt: Date?
    private(set) var windowOpensAt: Date?
    private(set) var bypassPending = false

    var isArmed: Bool { state == .armed }

    /// Arms a dormant machine after a deferrable launch verdict. The first
    /// window opens a full (jittered) `initialDelay` after `now`: the launch
    /// probe has only just failed, so an instant retry would be doomed.
    mutating func arm(at now: Date, jitter: Double = Self.randomJitter()) {
        guard state == .dormant else { return }
        state = .armed
        attemptCount = 0
        lastAttemptAt = nil
        bypassPending = false
        windowOpensAt = now.addingTimeInterval(Self.initialDelay * jitter)
    }

    /// Gates one trigger. Returns true to admit an attempt — recording its
    /// start and consuming any pending bypass — or false to drop the trigger.
    /// The floor is absolute: a bypass blocked by it is retained for the next
    /// trigger rather than consumed.
    mutating func admitTrigger(at now: Date) -> Bool {
        guard state == .armed else { return false }
        guard attemptCount < Self.maxAttempts else { return false }
        if let lastAttemptAt, now.timeIntervalSince(lastAttemptAt) < Self.interAttemptFloor {
            return false
        }
        if bypassPending {
            bypassPending = false
        } else if let windowOpensAt, now < windowOpensAt {
            return false
        }
        attemptCount += 1
        lastAttemptAt = now
        return true
    }

    /// An admitted attempt failed transiently: open the next window with
    /// exponential backoff (doubling from `initialDelay` up to the `maxDelay`
    /// ceiling) and ±`jitterSpread` jitter.
    mutating func recordFailure(at now: Date, jitter: Double = Self.randomJitter()) {
        guard state == .armed else { return }
        let base = min(Self.initialDelay * pow(2, Double(attemptCount)), Self.maxDelay)
        windowOpensAt = now.addingTimeInterval(base * jitter)
    }

    /// Bring-up succeeded: latch the machine shut.
    mutating func recordSuccess() {
        state = .completed
    }

    /// The deferral can no longer be resolved by retrying (signed out, or the
    /// session expired terminally): back to dormant.
    mutating func standDown() {
        guard state == .armed else { return }
        state = .dormant
    }

    /// External evidence that the blocking cause is gone (a network
    /// offline→online transition, or first unlock for a locked-keychain
    /// deferral): admit the next trigger regardless of the backoff window. The
    /// network path also grants a fresh attempt budget. The floor is never
    /// bypassed.
    mutating func noteStateChange(resettingAttempts: Bool) {
        guard state == .armed else { return }
        bypassPending = true
        if resettingAttempts {
            attemptCount = 0
        }
    }

    static func randomJitter() -> Double {
        Double.random(in: (1 - jitterSpread)...(1 + jitterSpread))
    }
}
