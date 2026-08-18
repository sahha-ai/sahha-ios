import Foundation

/// Lock discipline: `dedupLock` guards `postedOrigins` and `capNoticeRecorded`, and both
/// are touched only inside `admit(_:)`. Everything else is immutable, so the class stays
/// safely Sendable despite the mutable dedup state.
final class ErrorLogger: ErrorLoggerProtocol, @unchecked Sendable {
    /// Ceiling on distinct resolved origins posted per logger instance. The logger lives
    /// in the DI container, so the dedup set (and this cap) resets on deauthentication.
    static let maxDistinctOrigins = 128

    private let errorLoggingService: ErrorLoggingServiceProtocol
    private let deviceInfoBuilder: DeviceInfoBuilderProtocol
    private let circuitBreaker: CircuitBreaker?

    private let dedupLock = NSLock()
    private var postedOrigins: Set<String> = []
    private var capNoticeRecorded = false

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

        // The gate is synchronous and keyed on the same resolved origin the payload
        // reports, so a concurrent burst of identical errors admits exactly one
        // before any posting task is spawned.
        let origin = resolvedOrigin(for: error, file: file, function: function, line: line)
        switch admit(origin) {
        case .admitted:
            spawnPost(error, file: file, function: function, line: line)
        case .duplicateOrigin:
            return
        case .capReached(let recordNotice):
            // Recorded once, so a capped process is distinguishable from a quiet one.
            guard recordNotice else { return }
            spawnPost(
                SahhaError(message: "Error log limit reached: \(Self.maxDistinctOrigins) distinct error origins were posted by this process; further new origins are suppressed."),
                file: file,
                function: function,
                line: line
            )
        }
    }

    private enum Admission {
        case admitted
        case duplicateOrigin
        case capReached(recordNotice: Bool)
    }

    private func admit(_ origin: CodeOrigin) -> Admission {
        let signature = "\(origin.path)|\(origin.method)|\(origin.line)"
        dedupLock.lock()
        defer { dedupLock.unlock() }
        if postedOrigins.contains(signature) {
            return .duplicateOrigin
        }
        guard postedOrigins.count < Self.maxDistinctOrigins else {
            let recordNotice = !capNoticeRecorded
            capNoticeRecorded = true
            return .capReached(recordNotice: recordNotice)
        }
        postedOrigins.insert(signature)
        return .admitted
    }

    private func spawnPost(_ error: any Error, file: StaticString, function: StaticString, line: UInt) {
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

    /// The provenance a posted error resolves to — shared by the dedup gate and the
    /// payload builder so the two can never disagree about an error's identity.
    private func resolvedOrigin(for error: Error, file: StaticString, function: StaticString, line: UInt) -> CodeOrigin {
        resolve(
            error: error,
            fallback: CodeOrigin(path: file.description, method: function.description, line: line)
        ).origin
    }

    /// Walks SahhaError wrappers: prefers the throw site captured by SahhaError over the
    /// logging call site — errors funneled through forwarding helpers (e.g.
    /// SahhaActor.logError) all share one call site, which says nothing about where the
    /// failure happened. Returns the innermost error to shape the payload from (a
    /// SahhaError wrapping an API failure must report the underlying status code and
    /// location, not fall through to the generic SDK-error shape) and the deepest
    /// captured throw site as the origin.
    private func resolve(error: Error, fallback: CodeOrigin) -> (error: Error, origin: CodeOrigin) {
        guard let sahhaError = error as? SahhaError else {
            return (error, fallback)
        }
        let origin = CodeOrigin(path: sahhaError.file, method: sahhaError.function, line: sahhaError.line)
        guard let underlying = sahhaError.error else {
            return (sahhaError, origin)
        }
        return resolve(error: underlying, fallback: origin)
    }

    private func makeErrorLogRequest(
        error: Error,
        deviceInfo: DeviceInfo,
        file: StaticString,
        function: StaticString,
        line: UInt
    ) -> ErrorLogRequest {
        let (resolvedError, origin) = resolve(
            error: error,
            fallback: CodeOrigin(path: file.description, method: function.description, line: line)
        )
        switch resolvedError {
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
                errorMessage: resolvedError.localizedDescription,
                errorBody: String(describing: resolvedError),
                codePath: origin.path,
                codeMethod: origin.method,
                codeBody: "line \(origin.line)"
            )
        }
    }
}
