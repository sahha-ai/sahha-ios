import HealthKit

/// Normaliser for binary reproductive health flag category types:
///   - intermenstrual_bleeding
///   - infrequent_menstrual_cycles
///   - irregular_menstrual_cycles
///   - persistent_intermenstrual_bleeding
///   - prolonged_menstrual_periods
///   - pregnancy
///   - lactation
///
/// These types use HKCategoryValue.notApplicable as their only value — the presence
/// of a sample records that the condition was observed during the sample's time window.
/// value is always 1.0 to indicate presence (consistent with Android's event-marker pattern).
final class HKReproductiveFlagToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        return [
            DataLog(
                logType: sensor.dataLogType,
                dataType: sensor.rawValue,
                value: 1.0,
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
