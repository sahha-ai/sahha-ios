protocol LoggingServiceProtocol: Sendable {
    func postError(_ error: ErrorRequest) async
}
