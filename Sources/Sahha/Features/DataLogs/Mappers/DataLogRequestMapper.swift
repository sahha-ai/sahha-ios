import Foundation

final class DataLogRequestMapper: DataLogRequestMapperProtocol {
    private let deviceId: String
    private let logger: ErrorLoggerProtocol
    
    init(deviceId: String, logger: ErrorLoggerProtocol) {
        self.deviceId = deviceId
        self.logger = logger
    }
    
    func map(_ log: DataLog) -> DataLogRequest {
        buildRequestBody(for: log)
    }

    func map(_ logs: [DataLog]) -> [DataLogRequest] {
        logs.map(buildRequestBody)
    }
    
    private func buildRequestBody(for log: DataLog) -> DataLogRequest {
        DataLogRequest(
            id: log.id,
            parentId: log.parentId,
            logType: log.logType.stringValue,
            dataType: log.dataType,
            value: log.value,
            unit: log.unit,
            source: log.source,
            recordingMethod: log.recordingMethod.stringValue,
            deviceType: log.deviceType,
            startDateTime: log.startDate.isoDateTime,
            endDateTime: log.endDate.isoDateTime,
            additionalProperties:log.additionalProperties,
            deviceId: deviceId
        )
    }
        
}
