protocol DataLogServiceProtocol: Sendable {
    func postDataLogs(_ logs: [DataLog]) async throws
}
