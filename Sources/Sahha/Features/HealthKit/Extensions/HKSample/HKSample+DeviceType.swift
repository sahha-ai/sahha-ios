import HealthKit

extension HKSample {
    @inline(__always)
    var deviceType: String {
        return self.sourceRevision.productType ?? "unknown"
    }
}
