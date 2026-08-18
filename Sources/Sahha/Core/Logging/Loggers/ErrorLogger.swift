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
                    Sahha.log("[\(SDK.name)] - ERROR: Skipping error log - circuit breaker is open")
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
                Sahha.log("[\(SDK.name)] - ERROR: Failed to post error log: \(error)")
            }

        }
    }

    private func shouldPostError(_ error: Error) -> Bool {
        // Skip cancellation errors - these are expected during task cancellation
        if error is CancellationError {
            return false
        }
        
        // Skip "Protected health data is inaccessible" - expected when device is locked
        let desc = error.localizedDescription
        if desc.localizedCaseInsensitiveContains("protected health data") {
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

    /// The code-site values reported as codePath/codeMethod/codeBody.
    private struct CodeOrigin {
        let path: String
        let method: String
        let line: UInt
    }

    private func makeErrorLogRequest(
        error: Error,
        deviceInfo: DeviceInfo,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) -> ErrorLogRequest {
        makeErrorLogRequest(
            error: error,
            deviceInfo: deviceInfo,
            origin: CodeOrigin(path: file.description, method: function.description, line: line)
        )
    }

    private func makeErrorLogRequest(
        error: Error,
        deviceInfo: DeviceInfo,
        origin callSiteOrigin: CodeOrigin
    ) -> ErrorLogRequest {
        // Prefer the throw site captured by SahhaError over the logging call site — errors
        // funneled through forwarding helpers (e.g. SahhaActor.logError) all share one call
        // site, which says nothing about where the failure happened.
        var origin = callSiteOrigin
        if let sahhaError = error as? SahhaError {
            origin = CodeOrigin(path: sahhaError.file, method: sahhaError.function, line: sahhaError.line)
            // A SahhaError wrapping an API failure (e.g. "Session expired" wrapping the 401 that
            // killed the session) must report the underlying status code and location, not fall
            // through to the generic SDK-error shape.
            if let underlying = sahhaError.error {
                return makeErrorLogRequest(error: underlying, deviceInfo: deviceInfo, origin: origin)
            }
        }
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
                codePath: origin.path,
                codeMethod: origin.method,
                codeBody: "line \(origin.line)"
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
                // SDK-sourced errors have no API location; report the framework the SDK runs
                // as (sdkId carries the configured SahhaFramework rawValue, e.g. "ios_swift")
                // so the dashboard's location column isn't null.
                errorLocation: deviceInfo.sdkId,
                errorMessage: error.localizedDescription,
                errorBody: String(describing: error),
                codePath: origin.path,
                codeMethod: origin.method,
                codeBody: "line \(origin.line)"
            )
        }
    }
}
