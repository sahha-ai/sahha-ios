protocol LoggerProtocol: Sendable {
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
    func error(_ message: String, errorSource: ErrorSource, errorCode: Int, errorLocation: String, errorBody: String?)
}
