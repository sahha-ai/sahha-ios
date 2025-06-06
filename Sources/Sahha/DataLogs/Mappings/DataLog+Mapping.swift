import Foundation

extension DataLog {
    func toRequest() async -> DataLogRequest? {
        guard let sensor = SahhaSensor(dataType: dataType) else {return nil}
        
        let deviceId = await DeviceIdStore.shared.getDeviceId()
        let logType = sensor.logType.rawValue
        let unit = sensor.unitString
        let additionalPropertiesString = try? additionalProperties?.toJsonString() ?? ""
        let startDateTimeString = startDateTime.isoDateTime
        let endDateTimeString = endDateTime.isoDateTime
        let postDateTime = Date().isoDateTime
        
        let identifiers = [
            dataType,
            source,
            deviceType,
            startDateTimeString,
            endDateTimeString
        ]
        
        let id = UUIDFactory.v5(from: identifiers.joined(separator: "|")).uuidString
        
        return DataLogRequest(
            id: id,
            parentId: parentId,
            logType: logType,
            dataType: dataType,
            value: value,
            unit: unit,
            source: source,
            recordingMethod: recordingMethod.stringValue,
            deviceId: deviceId,
            deviceType: deviceType,
            startDateTime: startDateTimeString,
            endDateTime: endDateTimeString,
            postDateTime: postDateTime,
            additionalProperties: additionalPropertiesString
        )
    }
}
