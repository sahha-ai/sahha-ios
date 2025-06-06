import Foundation

class DataLogFormatter {
    private let calendar = Calendar(identifier: .gregorian)

    func format(_ log: DataLog) -> String {
        let valueString = String(format: "%.4f", log.value)

        let startSeconds = log.startDateTime.secondsSinceStartOfDay(calendar: calendar)
        let endSeconds = log.endDateTime.secondsSinceStartOfDay(calendar: calendar)

        let recordingMethod = log.recordingMethod.rawValue

        let parentId = log.parentId ?? "_"

        // TODO: implement schema-based compression
        let additionalProperties = "[]"

        return "\(valueString) \(startSeconds) \(endSeconds) \(recordingMethod) \(parentId) \(additionalProperties)"
    }
}
