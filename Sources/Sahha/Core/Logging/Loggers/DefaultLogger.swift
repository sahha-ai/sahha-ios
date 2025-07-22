import Foundation

final class DefaultLogger: Logger {
    private let api: APIClient
    private let deviceInfo: DeviceInformation

    init(api: APIClient, deviceInfo: DeviceInformation) {
        self.api = api
        self.deviceInfo = deviceInfo
    }

    func log(
        level: LogLevel,
        message: String,
        file: String,
        function: String,
        line: Int,
        source: String,
        code: Int?,
        location: String?,
        body: String?
    ) {
        let timestamp = Date().isoDateTime
        let fileName = (file as NSString).lastPathComponent

        print("[\(timestamp)] [\(level.rawValue)] [\(fileName):\(function):\(line)] - \(message)")

        guard level == .error else { return }

        let payload = ErrorRequest(
            sdkId: deviceInfo.sdkId,
            sdkVersion: deviceInfo.sdkVersion,
            appId: deviceInfo.appId,
            appVersion: deviceInfo.appVersion,
            deviceId: deviceInfo.deviceId,
            deviceType: deviceInfo.deviceType,
            deviceModel: deviceInfo.deviceModel,
            system: deviceInfo.system,
            systemVersion: deviceInfo.systemVersion,
            errorSource: source,
            errorCode: code,
            errorLocation: location,
            errorMessage: message,
            errorBody: body,
            codePath: file,
            codeMethod: function,
            codeBody: nil
        )

        let request = APIRequest(endpoint: APIEndpoints.error, method: .POST, body: payload)

        Task.detached(priority: .utility) { [weak self] in
            try? await self?.api.send(request)
        }
    }
}
