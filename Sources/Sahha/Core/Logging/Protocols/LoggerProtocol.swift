protocol LoggerProtocol: Sendable {
    func info(_ message: String, file: String?, function: String?)
    func warning(_ message: String, file: String?, function: String?)
    func error(
        _ message: String,
        errorCode: Int?,
        errorSource: ErrorSource,
        errorLocation: String?,
        errorBody: String?,
        codeBody: String?,
        file: String?,
        function: String?
    )
}
