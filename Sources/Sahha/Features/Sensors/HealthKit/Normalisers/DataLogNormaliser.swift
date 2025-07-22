import HealthKit

struct DataLogNormaliser {
    private static let registry: [SahhaSensor: @Sendable ([HKSample], SahhaSensor) -> [DataLog]] = [
        .heart_rate: HeartRateToDataLog.normalise,
        .resting_heart_rate: HeartRateToDataLog.normalise,
        .walking_heart_rate_average: HeartRateToDataLog.normalise,
        .heart_rate_variability_sdnn: HeartRateToDataLog.normalise,
        .vo2_max: VO2MaxToDataLog.normalise,
        .blood_glucose: BloodGlucoseToDataLog.normalise,
        .sleep: SleepToDataLog.normalise,
        .exercise: ExerciseToDataLog.normalise,
    ]

    private static let fallback: @Sendable ([HKSample], SahhaSensor) -> [DataLog] = { samples, sensor in
        return samples.compactMap { sample in
            guard let qtySample = sample as? HKQuantitySample, let unit = sensor.hkUnit else {
                return nil
            }

            return DataLog(
                logType: sensor.logType,
                dataType: sensor.rawValue,
                value: qtySample.quantity.doubleValue(for: unit).rounded(toPlaces: 4),
                unit: sensor.unitString,
                source: qtySample.sourceId,
                recordingMethod: qtySample.recordingMethod,
                deviceType: qtySample.deviceType,
                startDate: qtySample.startDate,
                endDate: qtySample.endDate
            )
        }
    }

    static func normalise(_ samples: [HKSample], sensor: SahhaSensor) -> [DataLog] {
        let normaliser = registry[sensor] ?? fallback
        return normaliser(samples, sensor)
    }
}
