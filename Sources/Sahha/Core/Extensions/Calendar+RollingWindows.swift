import Foundation

extension Calendar {
    func rollingWindows(
        from startDate: Date,
        to endDate: Date,
        duration: TimeInterval
    ) -> AnySequence<DateInterval> {
        var nextInterval = DateInterval(start: startDate, duration: duration)
        return AnySequence {
            AnyIterator {
                guard nextInterval.end <= endDate else { return nil }
                defer {
                    nextInterval = DateInterval(
                        start: nextInterval.end,
                        duration: duration
                    )
                }
                return nextInterval
            }
        }
    }
}
