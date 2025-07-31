protocol DataLogRequestMapperProtocol: Sendable {
    func map(_ log: DataLog) -> DataLogRequest
    func map(_ logs: [DataLog]) -> [DataLogRequest]
}
