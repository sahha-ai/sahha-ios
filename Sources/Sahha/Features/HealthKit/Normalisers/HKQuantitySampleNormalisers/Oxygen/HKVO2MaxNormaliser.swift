import HealthKit

struct HKVO2MaxNormaliser: HKNormaliser {
    static let metadataMappings: MetadataMapping = [
        HKMetadataKeyHeartRateSensorLocation: (
            propertyName: "measurement_method",
            mapper: enumMapper(for: HKVO2MaxTestType.self)
        )
    ]

    func normalise(sample: HKSample) -> [DataLog]? {
        let type = HKQuantityType.quantityType(forIdentifier: .vo2Max)

        guard let quantitySample = sample as? HKQuantitySample, quantitySample.quantityType == type, let unit = quantitySample.unit else {
            return nil
        }

        let value = quantitySample.quantity.doubleValue(for: unit).rounded(toPlaces: 4)

        let log = DataLog(
            parentId: nil,
            logType: quantitySample.logType,
            dataType: quantitySample.dataType,
            value: value,
            unit: quantitySample.unitString,
            source: quantitySample.sourceId,
            recordingMethod: quantitySample.recordingMethod,
            deviceType: quantitySample.deviceType,
            startDate: quantitySample.startDate,
            endDate: quantitySample.endDate,
            additionalProperties: extractAdditionalProperties(from: quantitySample, using: Self.metadataMappings)
        )

        return [log]
    }
}

extension HKVO2MaxTestType: StringRepresentable {
    var stringValue: String {
        switch self {
        case .maxExercise: return "max_exercise"
        case .predictionNonExercise: return "prediction_non_exercise"
        case .predictionSubMaxExercise: return "prediction_sub_max_exercise"
        @unknown default: return "unknown"
        }
    }
}
