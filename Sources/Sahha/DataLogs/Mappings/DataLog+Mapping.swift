import Foundation

extension DataLog {
    func toRequest() async -> DataLogRequest? {
        guard let sensor = SahhaSensor(dataType: dataType) else { return nil }
        
        let deviceId = await DeviceIdStore.shared.getDeviceId()
        let logType = sensor.logType.rawValue
        let unit = sensor.unitString
       
        let additionalPropertiesString: String?
        do {
            additionalPropertiesString = try additionalProperties?.toRequestPayload()?.toJsonString()
        } catch {
            print(error.localizedDescription)
            additionalPropertiesString = nil
        }
        
        return DataLogRequest(
            id: generateId().uuidString,
            parentId: parentId,
            logType: logType,
            dataType: dataType,
            value: value,
            unit: unit,
            source: source,
            recordingMethod: recordingMethod.stringValue,
            deviceId: deviceId,
            deviceType: deviceType,
            startDateTime: startDateTime.isoDateTime,
            endDateTime: endDateTime.isoDateTime,
            postDateTime: Date().isoDateTime,
            additionalProperties: additionalPropertiesString
        )
    }
}
