extension Logger {
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line, source: "SDK", code: nil, location: nil, body: nil)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line, source: "SDK", code: nil, location: nil, body: nil)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line, source: "SDK", code: nil, location: nil, body: nil)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line, source: "SDK", code: nil, location: nil, body: nil)
    }
    
    func apiError(_ message: String,code: Int, location: String, body: String) {
        log(level: .error, message: message, file: "", function: "", line: 0, source: "API", code: code, location: location, body: body)
    }
}
