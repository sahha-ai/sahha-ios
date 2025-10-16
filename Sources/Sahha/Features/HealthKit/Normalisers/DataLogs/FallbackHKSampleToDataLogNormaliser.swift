import HealthKit

final class FallbackHKSampleToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKQuantitySample,
            let sensor = sample.quantityType.sahhaSensor,
            let unit = sensor.hkUnit
        else { return [] }

        return [
            DataLog(
                logType: sensor.dataLogType,
                dataType: sensor.rawValue,
                value: sample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
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
