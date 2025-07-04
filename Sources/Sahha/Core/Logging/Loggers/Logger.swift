protocol LoggerProtocol: Sendable {
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String, file: String, function: String)
    func error(_ message: String, errorSource: ErrorSource, errorCode: Int, errorLocation: String, errorBody: String?)
}

final class Logger: LoggerProtocol {
    private let loggingService: LoggingServiceProtocol
    private let deviceInformation: DeviceInformation

    init(loggingService: LoggingServiceProtocol, deviceInformation: DeviceInformation) {
        self.loggingService = loggingService
        self.deviceInformation = deviceInformation
    }

    func info(_ message: String) {
        log(message, file: #file, function: #function, logLevel: .info)
    }

    func warning(_ message: String) {
        log(message, file: #file, function: #function, logLevel: .warning)
    }

    func error(_ message: String, file: String = #file, function: String = #function) {
        error(message, errorCode: nil, errorSource: .sdk, errorLocation: nil, errorBody: nil, codeBody: nil, file: file, function: function)
    }

    func error(_ message: String, errorSource: ErrorSource = .api, errorCode: Int, errorLocation: String, errorBody: String? = nil) {
        error(message, errorCode: errorCode, errorSource: errorSource, errorLocation: errorLocation, errorBody: errorBody, file: #file, function: #function)
    }

    private func error(
        _ message: String,
        errorCode: Int? = nil,
        errorSource: ErrorSource = .sdk,
        errorLocation: String? = nil,
        errorBody: String? = nil,
        codeBody: String? = nil,
        file: String,
        function: String
    ) {
        log(message, file: file, function: function, logLevel: .error)

        let request = ErrorRequest(
            sdkId: deviceInformation.sdkId,
            sdkVersion: deviceInformation.sdkVersion,
            appId: deviceInformation.appId,
            appVersion: deviceInformation.appVersion,
            deviceId: deviceInformation.deviceId,
            deviceType: deviceInformation.deviceType,
            deviceModel: deviceInformation.deviceModel,
            system: deviceInformation.system,
            systemVersion: deviceInformation.systemVersion,
            errorSource: errorSource.rawValue,
            errorCode: errorCode,
            errorLocation: errorLocation,
            errorMessage: message,
            errorBody: errorBody,
            codePath: file,
            codeMethod: function,
            codeBody: codeBody
        )

        Task {
            await loggingService.postError(request)
        }
    }

    private func log(_ message: String, file: String, function: String, logLevel: LogLevel) {
        print("\(logLevel.title) [\(file):\(function)] \(message)")
    }
}
