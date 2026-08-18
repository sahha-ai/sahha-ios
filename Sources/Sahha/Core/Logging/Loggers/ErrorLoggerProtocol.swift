protocol ErrorLoggerProtocol: Sendable {
    func postError(_ error: Error, file: StaticString, function: StaticString, line: UInt)
}

extension ErrorLoggerProtocol {
    /// The defaults resolve at the call site, so they identify wherever `postError` was
    /// called — not necessarily where the error was thrown. Forwarding helpers must pass
    /// their caller's values through explicitly, and errors that capture their own throw
    /// site (SahhaError) take precedence over these values in the logged payload.
    func postError(_ error: Error, file: StaticString = #fileID, function: StaticString = #function, line: UInt = #line) {
        postError(error, file: file, function: function, line: line)
    }
}
