import HealthKit

struct HKBloodGlucoseNormaliser: HKNormaliser {
    static let metadataMappings: MetadataMapping = [
        HKMetadataKeyBloodGlucoseMealTime: (
            propertyName: "relation_to_meal",
            mapper: enumMapper(for: HKBloodGlucoseMealTime.self)
        )
    ]

    func normalise(sample: HKSample) -> [DataLog]? {
        let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)

        guard let quantitySample = sample as? HKQuantitySample,
            quantitySample.quantityType == type,
            let sensor = SahhaSensor.sensor(for: quantitySample.quantityType),
            let unit = sensor.hkUnit
        else {
            return nil
        }

        let value = quantitySample.quantity.doubleValue(for: unit).rounded(toPlaces: 4)

        let log = DataLog(
            parentId: nil,
            logType: sensor.logType,
            dataType: sensor.rawValue,
            value: value,
            unit: sensor.unitString,
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

extension HKBloodGlucoseMealTime: StringRepresentable {
    var stringValue: String {
        switch self {
        case .preprandial: return "before_meal"
        case .postprandial: return "after_meal"
        @unknown default: return "unknown"
        }
    }
}
