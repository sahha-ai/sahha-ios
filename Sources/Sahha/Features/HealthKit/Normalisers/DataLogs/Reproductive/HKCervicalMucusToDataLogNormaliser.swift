import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.cervicalMucusQuality → DataLog.
///
/// value maps to the platform-agnostic CervicalMucusEnum ordinal (aligned with Android):
///   0.0 = UNKNOWN
///   1.0 = DRY
///   2.0 = STICKY
///   3.0 = CREAMY
///   4.0 = WATERY
///   5.0 = EGG_WHITE
///
/// Note: Android defines 6.0 = UNUSUAL (Health Connect only — no HealthKit equivalent).
final class HKCervicalMucusToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueCervicalMucusQuality(rawValue: sample.value)?.cervicalMucusValue ?? CervicalMucusEnum.unknown.value

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

extension HKCategoryValueCervicalMucusQuality {
    /// Maps to platform-agnostic CervicalMucusEnum ordinal (aligned with Android).
    fileprivate var cervicalMucusValue: Double {
        switch self {
        case .dry:      return CervicalMucusEnum.dry.value
        case .sticky:   return CervicalMucusEnum.sticky.value
        case .creamy:   return CervicalMucusEnum.creamy.value
        case .watery:   return CervicalMucusEnum.watery.value
        case .eggWhite: return CervicalMucusEnum.eggWhite.value
        @unknown default: return CervicalMucusEnum.unknown.value
        }
    }
}
