import HealthKit

protocol HKSampleToSahhaSampleNormaliserProtocol: Sendable {
    func normalise(_ sample: HKSample) -> [SahhaSample]
}
