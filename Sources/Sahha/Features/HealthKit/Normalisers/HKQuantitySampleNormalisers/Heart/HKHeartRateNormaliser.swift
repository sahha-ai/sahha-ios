import HealthKit

struct HKHeartRateNormaliser: HKNormaliser {
    static let metadataMappings: MetadataMapping = [
        HKMetadataKeyHeartRateSensorLocation: (
            propertyName: "measurement_location",
            mapper: enumMapper(for: HKHeartRateSensorLocation.self)
        ),
        HKMetadataKeyHeartRateMotionContext: (
            propertyName: "motion_context",
            mapper: enumMapper(for: HKHeartRateMotionContext.self)
        )
    ]

    func normalise(sample: HKSample) -> [DataLog]? {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)

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

extension HKHeartRateSensorLocation: StringRepresentable {
    var stringValue: String {
        switch self {
        case .chest: return "chest"
        case .earLobe: return "ear_lobe"
        case .finger: return "finger"
        case .foot: return "foot"
        case .hand: return "hand"
        case .wrist: return "wrist"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }
}

extension HKHeartRateMotionContext: StringRepresentable {
    var stringValue: String {
        switch self {
        case .notSet: return "not_set"
        case .sedentary: return "sedentary"
        case .active: return "active"
        @unknown default: return "unknown"
        }
    }
}
