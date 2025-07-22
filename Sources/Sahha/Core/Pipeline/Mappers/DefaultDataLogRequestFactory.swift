import Foundation

final class DefaultDataLogRequestFactory: DataLogRequestFactory {
    private let deviceIdStore: DeviceIdStore

    init(deviceIdStore: DeviceIdStore) {
        self.deviceIdStore = deviceIdStore
    }

    func makeRequest(from log: DataLog) async -> DataLogRequest {
        let deviceId = await deviceIdStore.getId()

        let additionalProperties: String? = {
            guard
                let props = log.additionalProperties,
                let data = try? JSONEncoder().encode(props),
                let json = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return json
        }()

        return DataLogRequest(
            id: log.id,
            parentId: log.parentId,
            logType: log.logType.stringValue,
            dataType: log.dataType,
            value: log.value,
            unit: log.unit,
            source: log.source,
            recordingMethod: log.recordingMethod.stringValue,
            deviceType: log.deviceType,
            startDate: log.startDate,
            endDate: log.endDate,
            additionalProperties: additionalProperties,
            deviceId: deviceId
        )
    }
}
