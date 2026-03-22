import HealthKit

/// Normaliser for HKCategoryTypeIdentifier.menstrualFlow → DataLog.
///
/// value maps to the platform-agnostic MenstrualFlowEnum ordinal (aligned with Android):
///   0.0 = UNKNOWN    (HK: unspecified)
///   1.0 = NONE       (HK: notPresent — flow explicitly recorded as absent)
///   2.0 = LIGHT
///   3.0 = MEDIUM
///   4.0 = HEAVY
///
/// additionalProperties["cycle_start"] — "true" if this sample marks the
/// start of a new menstrual cycle (HKMetadataKeyMenstrualCycleStart).
final class HKMenstrualFlowToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKCategorySample,
            let sensor = sample.categoryType.sahhaSensor
        else { return [] }

        let value = HKCategoryValueMenstrualFlow(rawValue: sample.value)?.menstrualFlowValue ?? MenstrualFlowEnum.unknown.value

        var properties: [String: String] = [:]
        if let isCycleStart = sample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool {
            properties["cycle_start"] = String(isCycleStart)
        }

        let additionalProperties: [String: String]? = properties.isEmpty ? nil : properties

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
                endDate: sample.endDate,
                additionalProperties: additionalProperties
            )
        ]
    }
}

extension HKCategoryValueMenstrualFlow {
    /// Maps to platform-agnostic MenstrualFlowEnum ordinal (aligned with Android).
    fileprivate var menstrualFlowValue: Double {
        switch self {
        case .unspecified: return MenstrualFlowEnum.unknown.value
        case .notPresent:  return MenstrualFlowEnum.none.value
        case .light:       return MenstrualFlowEnum.light.value
        case .medium:      return MenstrualFlowEnum.medium.value
        case .heavy:       return MenstrualFlowEnum.heavy.value
        @unknown default:  return MenstrualFlowEnum.unknown.value
        }
    }
}
