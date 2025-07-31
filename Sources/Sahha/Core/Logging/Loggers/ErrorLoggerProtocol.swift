protocol ErrorLoggerProtocol: Sendable {
    func postError(_ error: Error, file: StaticString, function: StaticString, line: UInt)
}

extension ErrorLoggerProtocol {
    func postError(_ error: Error, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        postError(error, file: file, function: function, line: line)
    }
}
