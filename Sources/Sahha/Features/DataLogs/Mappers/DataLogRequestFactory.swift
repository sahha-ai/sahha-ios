import Foundation

final class DataLogRequestFactory: DataLogRequestMapping {
    private let deviceIdStore: DeviceIdStoring

    init(deviceIdStore: DeviceIdStoring) {
        self.deviceIdStore = deviceIdStore
    }

    func map(_ log: DataLog) async throws -> DataLogRequest {
        let deviceId = try await deviceIdStore.getDeviceId()
        return makeRequest(log, deviceId: deviceId)
    }

    func map(_ logs: [DataLog]) async throws -> [DataLogRequest] {
        let deviceId = try await deviceIdStore.getDeviceId()
        return logs.map{ makeRequest($0, deviceId: deviceId) }
    }

    private func makeRequest(_ log: DataLog, deviceId: String) -> DataLogRequest {
        let additionalPropertiesString: String? = {
            guard
                let props = log.additionalProperties,
                let data = try? JSONEncoder().encode(props),
                let jsonString = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return jsonString
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
            additionalProperties: additionalPropertiesString,
            deviceId: deviceId
        )
    }
}
