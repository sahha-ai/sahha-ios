import HealthKit

protocol HKSampleToTagNormaliserProtocol: Sendable {
    func normalise(_ sample: HKSample) -> [Tag]
}
