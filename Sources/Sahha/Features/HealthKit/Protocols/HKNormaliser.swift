import HealthKit

protocol HKNormaliser: Sendable {
    func normalise(sample: HKSample) -> [DataLog]?
}
