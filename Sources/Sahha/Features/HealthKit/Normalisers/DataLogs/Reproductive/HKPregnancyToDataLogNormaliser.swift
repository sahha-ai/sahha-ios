import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.pregnancyTestResult → DataLog.
///
/// value maps to the platform-agnostic PregnancyTestEnum ordinal (aligned with Android):
///   0.0 = INCONCLUSIVE  (HK: indeterminate)
///   1.0 = NEGATIVE
///   2.0 = POSITIVE
///
/// Note: HK's `indeterminate` maps to INCONCLUSIVE (0.0) — Android has no
/// separate INDETERMINATE case.
final class HKPregnancyTestToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValuePregnancyTestResult(rawValue: sample.value)?.pregnancyTestValue ?? PregnancyTestEnum.inconclusive.value

        return [
            DataLog(
                logType: sensor.dataLogType,
                dataType: sensor.rawValue,
                value: value,
                unit: sensor.unitString,
                source: sample.sourceId,
                recordingMethod: sample.recordingMethod,
                deviceType: sample.deviceType,
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        ]
    }
}

extension HKCategoryValuePregnancyTestResult {
    /// Maps to platform-agnostic PregnancyTestEnum ordinal (aligned with Android).
    /// HK's `indeterminate` collapses to INCONCLUSIVE — Android has no separate INDETERMINATE case.
    fileprivate var pregnancyTestValue: Double {
        switch self {
        case .indeterminate: return PregnancyTestEnum.inconclusive.value
        case .negative:      return PregnancyTestEnum.negative.value
        case .positive:      return PregnancyTestEnum.positive.value
        @unknown default:    return PregnancyTestEnum.inconclusive.value
        }
    }
}
