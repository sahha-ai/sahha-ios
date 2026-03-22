import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.ovulationTestResult → DataLog.
///
/// value maps to the platform-agnostic OvulationTestEnum ordinal (aligned with Android):
///   0.0 = INCONCLUSIVE  (HC: RESULT_INCONCLUSIVE / HK: indeterminate)
///   1.0 = NEGATIVE      (HC: RESULT_NEGATIVE     / HK: negative)
///   2.0 = HIGH          (HC: RESULT_HIGH         / HK: estrogenSurge)
///   3.0 = POSITIVE      (HC: RESULT_POSITIVE     / HK: luteinizingHormoneSurge)
final class HKOvulationTestToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueOvulationTestResult(rawValue: sample.value)?.ovulationTestValue ?? OvulationTestEnum.inconclusive.value

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

extension HKCategoryValueOvulationTestResult {
    /// Maps to platform-agnostic OvulationTestEnum ordinal (aligned with Android).
    fileprivate var ovulationTestValue: Double {
        switch self {
        case .indeterminate:          return OvulationTestEnum.inconclusive.value
        case .negative:               return OvulationTestEnum.negative.value
        case .estrogenSurge:          return OvulationTestEnum.high.value
        case .luteinizingHormoneSurge: return OvulationTestEnum.positive.value
        @unknown default:             return OvulationTestEnum.inconclusive.value
        }
    }
}
