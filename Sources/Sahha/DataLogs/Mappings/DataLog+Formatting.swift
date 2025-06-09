import Foundation

extension DataLog {
    func asRawStorageLine() -> String {
        let baseDay = Calendar.current.startOfDay(for: startDateTime)
        let startSeconds = Int(startDateTime.timeIntervalSince(baseDay))
        let endSeconds = Int(endDateTime.timeIntervalSince(baseDay))

        let recordingMethodRaw = recordingMethod.rawValue
        let parent = parentId ?? "_"
        let props = additionalProperties?.serialise() ?? "_"

        return "\(value) \(startSeconds) \(endSeconds) \(recordingMethodRaw) \(parent) \(props)"
    }
}
