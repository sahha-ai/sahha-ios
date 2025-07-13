import Foundation

extension DataLog {
    func toRequest(deviceId: String) -> DataLogRequest {
        return DataLogRequest(
            id: id,
            parentId: parentId,
            logType: logType.stringValue,
            dataType: dataType,
            value: value,
            unit: unit,
            source: source,
            recordingMethod: recordingMethod.stringValue,
            deviceType: deviceType,
            startDate: startDate,
            endDate: endDate,
            additionalProperties: additionalProperties?.toJSONString(),
            deviceId: deviceId,
        )
    }
}
