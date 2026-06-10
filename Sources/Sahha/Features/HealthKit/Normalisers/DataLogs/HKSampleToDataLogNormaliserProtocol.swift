import HealthKit

protocol HKSampleToDataLogNormaliserProtocol: Sendable {
    func normalise(_ sample: HKSample, profileId: String?) -> [DataLog]

    /// Normalises a batch of samples. Most normalisers are per-sample (the
    /// default implementation), but some derive logs that span multiple
    /// samples (e.g. sleep sessions) and need the whole batch.
    func normalise(_ samples: [HKSample], profileId: String?) -> [DataLog]
}

extension HKSampleToDataLogNormaliserProtocol {
    func normalise(_ samples: [HKSample], profileId: String?) -> [DataLog] {
        samples.flatMap { normalise($0, profileId: profileId) }
    }
}
