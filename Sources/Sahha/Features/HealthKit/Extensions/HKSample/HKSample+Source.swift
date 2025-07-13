import HealthKit

extension HKSample {
    @inline(__always)
    var sourceId: String {
        return self.sourceRevision.source.bundleIdentifier
    }
}
