import Foundation
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

        guard let quantitySample = sample as? HKQuantitySample, quantitySample.quantityType == type else {
            return nil
        }

        let value = quantitySample.quantity.doubleValue(for: HKUnit(from: "count/min")).rounded(toPlaces: 4)

        let log = DataLog(
            parentId: nil,
            logType: quantitySample.logType,
            dataType: quantitySample.dataType,
            value: value,
            unit: "mg/dL",
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
