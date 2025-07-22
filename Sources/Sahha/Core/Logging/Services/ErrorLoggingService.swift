import Foundation

final class ErrorLoggingService: ErrorLogger {
    private let apiClient: APIClientProviding
    private let collector: DeviceInfoCollecting

    init(apiClient: APIClientProviding, collector: DeviceInfoCollecting) {
        self.apiClient = apiClient
        self.collector = collector
    }

    func postSdkError(_ message: String, error: Error, file: String, function: String, line: Int) {
        Task.detached(priority: .background) { [weak self] in
            guard let self,
                let deviceInfo = try? await self.collector.collect()
            else { return }

            let errorLog = self.buildErrorLog(
                deviceInfo: deviceInfo,
                errorSource: .sdk,
                message: message,
                error: error,
                codePath: (file as NSString).lastPathComponent,
                codeMethod: function,
                codeBody: "Line \(line)"
            )

            try? await self.apiClient.send(.postError(errorLog))
        }
    }

    func postApiError(errorCode: Int?, errorLocation: String?, errorMessage: String?, errorBody: String?) {
        Task.detached(priority: .background) { [weak self] in
            guard let self,
                let deviceInfo = try? await self.collector.collect()
            else { return }

            let errorLog = self.buildErrorLog(
                deviceInfo: deviceInfo,
                errorSource: .api,
                message: errorMessage,
                errorCode: errorCode,
                errorLocation: errorLocation,
                errorBody: errorBody
            )

            try? await self.apiClient.send(.postError(errorLog))
        }
    }

    private func buildErrorLog(
        deviceInfo: DeviceInformation,
        errorSource: ErrorSource,
        message: String? = nil,
        error: Error? = nil,
        errorCode: Int? = nil,
        errorLocation: String? = nil,
        errorBody: String? = nil,
        codePath: String? = nil,
        codeMethod: String? = nil,
        codeBody: String? = nil
    ) -> ErrorLog {
        ErrorLog(
            sdkId: deviceInfo.sdkId,
            sdkVersion: deviceInfo.sdkVersion,
            appId: deviceInfo.appId,
            appVersion: deviceInfo.appVersion,
            deviceId: deviceInfo.deviceId,
            deviceType: deviceInfo.deviceType,
            deviceModel: deviceInfo.deviceModel,
            system: deviceInfo.system,
            systemVersion: deviceInfo.systemVersion,
            errorSource: errorSource,
            errorCode: errorCode,
            errorLocation: errorLocation,
            errorMessage: message,
            errorBody: error?.localizedDescription ?? errorBody,
            codePath: codePath,
            codeMethod: codeMethod,
            codeBody: codeBody
        )
    }
}
