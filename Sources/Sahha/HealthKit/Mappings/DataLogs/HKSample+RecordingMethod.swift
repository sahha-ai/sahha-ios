import HealthKit

extension HKSample {
    var recordingMethod: DataLogRecordingMethod {
        guard let value = metadata?[HKMetadataKeyWasUserEntered] as? NSNumber else {
            return .unknown
        }
        return value.boolValue ? .manual : .automatic
    }
}
