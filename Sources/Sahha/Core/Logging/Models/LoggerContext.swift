enum LoggerContext: Sendable {
    case sdk(file: StaticString, line: UInt, function: StaticString, codeBody: String? = nil)
    case api(code: Int?, location: String?, body: String?)
}
