import Foundation

extension Date {
    /// HealthKit stores `Date.distantFuture` (4001-01-01 00:00:00 UTC) as the end
    /// date for open-ended / ongoing category samples — e.g. a current pregnancy,
    /// ongoing lactation, or an in-effect contraceptive method. There is no genuine
    /// end date yet, so callers should treat such samples as having no end.
    var isDistantFutureSentinel: Bool {
        self >= .distantFuture
    }
}
