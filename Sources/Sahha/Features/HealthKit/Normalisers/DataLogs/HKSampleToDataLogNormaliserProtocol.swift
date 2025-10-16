import HealthKit

protocol HKSampleToDataLogNormaliserProtocol: Sendable {
    func normalise(_ sample: HKSample) -> [DataLog]
}
