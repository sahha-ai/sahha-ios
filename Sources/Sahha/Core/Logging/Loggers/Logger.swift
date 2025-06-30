final class Logger: LoggerProtocol {
    private let loggingService: LoggingServiceProtocol
    private let deviceInfoManager: DeviceInformationManagerProtocol

    init(loggingService: LoggingServiceProtocol, deviceInfoManager: DeviceInformationManagerProtocol) {
        self.loggingService = loggingService
        self.deviceInfoManager = deviceInfoManager
    }

    func info(_ message: String) {
        log(message, file: #file, function: #function, logLevel: .info)
    }

    func warning(_ message: String) {
        log(message, file: #file, function: #function, logLevel: .warning)
    }

    func error(_ message: String) {
        error(message, errorCode: nil, errorSource: .sdk, errorLocation: nil, errorBody: nil, codeBody: nil)
    }

    func error(_ message: String, errorSource: ErrorSource = .api, errorCode: Int, errorLocation: String, errorBody: String? = nil) {
        error(message, errorCode: errorCode, errorSource: errorSource, errorLocation: errorLocation, errorBody: errorBody)
    }

    private func error(
        _ message: String,
        errorCode: Int? = nil,
        errorSource: ErrorSource = .sdk,
        errorLocation: String? = nil,
        errorBody: String? = nil,
        codeBody: String? = nil,
        file: String = #file,
        function: String = #function
    ) {
        log(message, file: file, function: function, logLevel: .error)

        Task {
            let deviceInfo = await deviceInfoManager.getDeviceInformation()
            let request = ErrorRequest(
                sdkId: deviceInfo.sdkId,
                sdkVersion: deviceInfo.sdkVersion,
                appId: deviceInfo.appId,
                appVersion: deviceInfo.appVersion,
                deviceId: deviceInfo.deviceId,
                deviceType: deviceInfo.deviceType,
                deviceModel: deviceInfo.deviceModel,
                system: deviceInfo.system,
                systemVersion: deviceInfo.systemVersion,
                errorSource: errorSource.rawValue,
                errorCode: errorCode,
                errorLocation: errorLocation,
                errorMessage: message,
                errorBody: errorBody,
                codePath: file,
                codeMethod: function,
                codeBody: codeBody
            )
            await loggingService.postError(request)
        }
    }

    private func log(_ message: String, file: String? = #file, function: String? = #function, logLevel: LogLevel) {
        #if DEBUG
            var logString = "\(logLevel.title)"
            if let file = file, let function = function {
                logString += " [\(file):\(function)]"
            }
            logString += ": \(message)"
            print(logString)
        #endif
    }
}
