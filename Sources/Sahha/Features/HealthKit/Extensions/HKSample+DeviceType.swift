import HealthKit

extension HKSample {
    var deviceType: String {
        return self.sourceRevision.productType ?? "unknown"
    }
}
