protocol Logger: Sendable {
    func log(
        level: LogLevel,
        message: String,
        file: String,
        function: String,
        line: Int,
        source: String,
        code: Int?,
        location: String?,
        body: String?,
    )
}
