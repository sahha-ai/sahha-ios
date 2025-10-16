protocol DataLogServiceProtocol: Sendable {
    func postDataLogs(_ logs: [DataLogRequest]) async throws
}
