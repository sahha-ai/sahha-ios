import Foundation

struct BatchRetryPolicy {
    let intervals: [TimeInterval]
    let repeatLastInterval: Bool

    func delay(forRetry retry: Int) -> TimeInterval? {
        if retry < intervals.count {
            return intervals[retry]
        } else if repeatLastInterval, let last = intervals.last {
            return last
        } else {
            return nil
        }
    }
}
