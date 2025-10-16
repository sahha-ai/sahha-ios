import HealthKit

extension HKSample {
    var recordingMethod: RecordingMethod {
        if let wasUserEntered = self.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber {
            return wasUserEntered.boolValue ? .manual : .automatic
        }
        return .unknown
    }
}
