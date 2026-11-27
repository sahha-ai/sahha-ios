import HealthKit

/// One page of an anchored query: its samples, how many deleted objects came with them,
/// and the anchor to resume from.
///
/// HealthKit returns deleted objects in the same pages as samples and counts them toward
/// the page's limit. After a large deletion (a sync app rewriting history, a removed
/// app's data, a cleared source) a page can hold deletions and no samples at all. That
/// page is not the end of the query: its anchor still moves past the deletions, and the
/// samples behind them arrive on later pages. Only a page with neither samples nor
/// deletions means the query has caught up.
struct AnchoredQueryPage: Sendable {
    let samples: [HKSample]
    let deletedObjectCount: Int
    let anchor: HKQueryAnchor?

    init(samples: [HKSample], deletedObjectCount: Int = 0, anchor: HKQueryAnchor?) {
        self.samples = samples
        self.deletedObjectCount = deletedObjectCount
        self.anchor = anchor
    }

    /// Neither samples nor deletions: the query has caught up.
    var isEmpty: Bool {
        samples.isEmpty && deletedObjectCount == 0
    }
}
