protocol ErrorLoggingServiceProtocol: Sendable {
    func postError(_ error: ErrorLogRequest) async throws
}
