import Foundation
import HealthKit

protocol HKSampleNormalizer {
    func normalize(_ sample: HKSample, source: String, deviceType: String, recordingMethod: DataLogRecordingMethod, startDate: Date, endDate: Date) -> [DataLog]?
}

class SensorNormalizer: Normalizable {
    typealias RawData = HKSample
    typealias LogType = [DataLog]
    
    private let normalizers: [String: HKSampleNormalizer] = [
            String(describing: HKQuantitySample.self): HKQuantitySampleNormalizer(),
            String(describing: HKCategorySample.self): HKCategorySampleNormalizer(),
            String(describing: HKWorkout.self): HKWorkoutNormalizer()
        ]
    
    func normalize(_ sample: HKSample) async -> [DataLog]? {
        let source = sample.sourceRevision.source.name
        let deviceType = sample.sourceRevision.productType ?? "Unknown"
        let startDate = sample.startDate
        let endDate = sample.endDate
        let recordingMethod = getRecordingMethod(sample)
        
        let key = String(describing: type(of: sample))
        if let normalizer = normalizers[key] {
            return normalizer.normalize(sample, source: source, deviceType: deviceType, recordingMethod: recordingMethod, startDate: startDate, endDate: endDate)
        } else {
            print("Unsupported sample type: \(sample.sampleType.identifier)")
            return nil
        }
    }
    
    private func getRecordingMethod(_ sample: HKSample) -> DataLogRecordingMethod {
        guard let value = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber else {
            return .unknown
        }
        return value.boolValue ? .manual : .automatic
    }
}
