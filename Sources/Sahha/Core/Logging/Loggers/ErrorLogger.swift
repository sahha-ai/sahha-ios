import Foundation

final class ErrorLogger: ErrorLoggerProtocol {
    private let errorLoggingService: ErrorLoggingServiceProtocol
    private let deviceInfoBuilder: DeviceInfoBuilderProtocol
    private let circuitBreaker: CircuitBreaker?

    init(
        errorLoggingService: ErrorLoggingServiceProtocol,
        deviceInfoBuilder: DeviceInfoBuilderProtocol,
        circuitBreaker: CircuitBreaker? = nil
    ) {
        self.errorLoggingService = errorLoggingService
        self.deviceInfoBuilder = deviceInfoBuilder
        self.circuitBreaker = circuitBreaker
    }

    func postError(_ error: any Error, file: StaticString, function: StaticString, line: UInt) {
        guard shouldPostError(error) else { return }
        
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            
            // Check circuit breaker health before attempting to post
            if let circuitBreaker = self.circuitBreaker {
                let isHealthy = await circuitBreaker.isHealthy()
                if !isHealthy {
                    #if DEBUG
                        print("[\(SDK.name)] - ERROR: Skipping error log - circuit breaker is open")
                    #endif
                    return
                }
            }
            
            let deviceInfo = await self.deviceInfoBuilder.build()
            let errorLog = self.makeErrorLogRequest(
                error: error,
                deviceInfo: deviceInfo,
                file: file,
                function: function,
                line: line
            )

            do {
                try await self.errorLoggingService.postError(errorLog)
            } catch {
                #if DEBUG
                    print("[\(SDK.name)] - ERROR: Failed to post error log: \(error)")
                #endif
            }

        }
    }

    private func shouldPostError(_ error: Error) -> Bool {
        // Skip cancellation errors - these are expected during task cancellation
        if error is CancellationError {
            return false
        }
        
        // Unwrap SahhaError to check underlying error
        if let sahhaError = error as? SahhaError {
            if let underlying = sahhaError.error {
                return shouldPostError(underlying)
            }
            return true
        }

        // Send all errors to server for visibility across all environments
        return true
    }

    private func makeErrorLogRequest(
        error: Error,
        deviceInfo: DeviceInfo,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) -> ErrorLogRequest {
        switch error {
        case let apiError as APIErrorResponse:
            let errorBody: String? = {
                if let data = try? JSONEncoder().encode(apiError.errors),
                    let jsonString = String(data: data, encoding: .utf8)
                {
                    return jsonString
                } else {
                    return apiError.errors.map { "\($0.origin): \($0.errors.joined(separator: ", "))" }
                        .joined(separator: " | ")
                }
            }()
            return ErrorLogRequest(
                sdkId: deviceInfo.sdkId,
                sdkVersion: deviceInfo.sdkVersion,
                appId: deviceInfo.appId,
                appVersion: deviceInfo.appVersion,
                deviceId: deviceInfo.deviceId,
                deviceType: deviceInfo.deviceType,
                deviceModel: deviceInfo.deviceModel,
                system: deviceInfo.system,
                systemVersion: deviceInfo.systemVersion,
                errorSource: ErrorSource.api.rawValue,
                errorCode: apiError.statusCode,
                errorLocation: apiError.location,
                errorMessage: apiError.title,
                errorBody: errorBody,
                codePath: file.description,
                codeMethod: function.description,
                codeBody: "line \(line)"
            )
        default:
            return ErrorLogRequest(
                sdkId: deviceInfo.sdkId,
                sdkVersion: deviceInfo.sdkVersion,
                appId: deviceInfo.appId,
                appVersion: deviceInfo.appVersion,
                deviceId: deviceInfo.deviceId,
                deviceType: deviceInfo.deviceType,
                deviceModel: deviceInfo.deviceModel,
                system: deviceInfo.system,
                systemVersion: deviceInfo.systemVersion,
                errorSource: ErrorSource.sdk.rawValue,
                errorCode: nil,
                errorLocation: nil,
                errorMessage: error.localizedDescription,
                errorBody: String(describing: error),
                codePath: file.description,
                codeMethod: function.description,
                codeBody: "line \(line)"
            )
        }
    }
}
