import Foundation

/// Groups time-ranged elements into sleep sessions. HealthKit has no session
/// object for sleep (unlike Health Connect), so sessions are derived by
/// chaining samples whose gap to the running session is within `sessionGap`.
enum SleepSessionGrouper {
    /// Maximum gap between a session's end and the next sample's start for
    /// the sample to belong to the same session.
    static let sessionGap: TimeInterval = 60 * 60

    /// Sorts elements by start date and splits them into sessions wherever
    /// the gap from the latest end seen so far exceeds `gap`. Overlapping and
    /// contained elements always share a session.
    static func groupIntoSessions<Element>(
        _ elements: [Element],
        start: (Element) -> Date,
        end: (Element) -> Date,
        gap: TimeInterval = sessionGap
    ) -> [[Element]] {
        guard !elements.isEmpty else { return [] }

        let sorted = elements.sorted { start($0) < start($1) }

        var sessions: [[Element]] = []
        var currentSession: [Element] = [sorted[0]]
        var currentSessionEnd = end(sorted[0])

        for element in sorted.dropFirst() {
            if start(element).timeIntervalSince(currentSessionEnd) > gap {
                sessions.append(currentSession)
                currentSession = [element]
                currentSessionEnd = end(element)
            } else {
                currentSession.append(element)
                currentSessionEnd = max(currentSessionEnd, end(element))
            }
        }

        sessions.append(currentSession)
        return sessions
    }
}
