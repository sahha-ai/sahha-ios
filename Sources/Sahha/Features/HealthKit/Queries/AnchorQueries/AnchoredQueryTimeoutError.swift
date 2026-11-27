import Foundation

/// An anchored-query page that did not return within its timeout.
///
/// The message stays short and stable: sensor and budget. The context travels in the
/// posted error body, so one field report can tell the likely causes apart: a first
/// sync on a large store, a crowded query queue, or a process suspended mid-query.
struct AnchoredQueryTimeoutError: LocalizedError, CustomStringConvertible {
    let sensor: SahhaSensor
    let seconds: TimeInterval
    let context: AnchoredQueryTimeoutContext

    /// True when the page was already at the smallest size, so shrinking pages
    /// further cannot help.
    var isAtMinimumPageSize: Bool { context.limit == context.nextLimit }

    var errorDescription: String? {
        let base = "HealthKit anchor query timed out for sensor \(sensor.rawValue) after \(Int(seconds))s"
        return isAtMinimumPageSize ? "\(base), even at the minimum page size of \(context.limit)" : base
    }

    /// The posted error body.
    var description: String {
        "AnchoredQueryTimeoutError(sensor: \(sensor.rawValue), timeout: \(Int(seconds))s, \(context))"
    }
}

/// What an anchored-query page was doing when it timed out.
struct AnchoredQueryTimeoutContext: Sendable, CustomStringConvertible {
    /// Page size the timed-out page requested.
    let limit: Int
    /// Page size the sensor's next page requests.
    let nextLimit: Int
    /// No anchor yet: the 30-day first sync, the costliest query the SDK runs.
    let isInitialSync: Bool
    /// Pages this run completed before the one that timed out.
    let pagesCompleted: Int
    /// Wall-clock seconds the page was outstanding when the timeout fired. Far above
    /// the budget means the process was suspended, or the device asleep, mid-query.
    let elapsed: TimeInterval
    /// Seconds the page queued for a query slot before its timeout started.
    let waitedForSlot: TimeInterval
    /// The shared query slots when the timeout fired. `inUse` counts this page.
    let slots: AsyncSemaphore.Load
    /// The app's state when the timeout fired; nil when no provider is wired.
    let appState: ApplicationStateSnapshot?

    var description: String {
        [
            "limit: \(limit)",
            "nextLimit: \(nextLimit)",
            "initialSync: \(isInitialSync)",
            "pagesCompleted: \(pagesCompleted)",
            "elapsed: \(Self.format(elapsed))",
            "waitedForSlot: \(Self.format(waitedForSlot))",
            "slotsInUse: \(slots.inUse)/\(slots.capacity)",
            "queuedForSlot: \(slots.waiting)",
            "app: \(appState.map { "(\($0))" } ?? "unknown")",
        ].joined(separator: ", ")
    }

    static func format(_ seconds: TimeInterval) -> String {
        String(format: "%.1fs", seconds)
    }
}
