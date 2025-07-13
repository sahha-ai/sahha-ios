extension Logger {
    func info(
        _ msg: @autoclosure @escaping @Sendable () -> String,
        file: StaticString = #fileID,
        line: UInt = #line,
        fn: StaticString = #function
    ) {
        log(.info, msg(), context: .sdk(file: file, line: line, function: fn))
    }
    
    func warning(
        _ msg: @autoclosure @escaping @Sendable () -> String,
        file: StaticString = #fileID,
        line: UInt = #line,
        fn: StaticString = #function
    ) {
        log(.warning, msg(), context: .sdk(file: file, line: line, function: fn))
    }
    
    func error(
        _ msg: @autoclosure @escaping @Sendable () -> String,
        file: StaticString = #fileID,
        line: UInt = #line,
        fn: StaticString = #function,
        codeBody: String? = nil
    ) {
        log(.error, msg(), context: .sdk(file: file, line: line, function: fn, codeBody: codeBody))
    }
    
    func apiError(
        _ msg: @autoclosure @escaping @Sendable () -> String,
        code: Int? = nil,
        location: String? = nil,
        body: String? = nil
    ) {
        log(.error, msg(), context: .api(code: code, location: location, body: body))
    }
}
