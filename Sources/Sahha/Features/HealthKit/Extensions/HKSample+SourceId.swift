import HealthKit

extension HKSample {
    var sourceId: String {
        return self.sourceRevision.source.bundleIdentifier
    }
}
