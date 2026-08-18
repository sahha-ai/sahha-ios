import Testing
import Foundation
import HealthKit
@testable import Sahha

// MARK: - Throw-site fixtures
//
// These helpers stand in for SDK code that throws: the origin a SahhaError captures
// must be the line that created it here, not wherever it was eventually logged.

private func makeThrowSiteError() -> (error: SahhaError, function: String, line: UInt) {
    let line = UInt(#line) + 1
    let error = SahhaError(message: "Sensor set cannot be empty.")
    return (error, #function, line)
}

private func makeSessionExpiredError(wrapping apiError: APIErrorResponse) -> (error: SahhaError, function: String, line: UInt) {
    let line = UInt(#line) + 1
    let error = SahhaError(message: "Session expired.", error: apiError)
    return (error, #function, line)
}

private func makeInnerError() -> (error: SahhaError, function: String, line: UInt) {
    let line = UInt(#line) + 1
    let error = SahhaError(message: "Keychain read failed.")
    return (error, #function, line)
}

/// Coverage of the error-log payload builder: SDK-source errors must report the
/// configured framework as errorLocation, and codePath/codeMethod/codeBody must point
/// at the real throw site (captured by SahhaError at creation) rather than the shared
/// logging call site (e.g. SahhaActor.logError) that forwards every public API error.
@Suite("ErrorLogger payloads")
struct ErrorLoggerPayloadTests {

    // MARK: - Test doubles

    /// Records posted error logs and lets tests await the ErrorLogger's detached task.
    private actor MockErrorLoggingService: ErrorLoggingServiceProtocol {
        private var pending: [ErrorLogRequest] = []
        private var waiters: [CheckedContinuation<ErrorLogRequest, Never>] = []

        func postError(_ request: ErrorLogRequest) async throws {
            if waiters.isEmpty {
                pending.append(request)
            } else {
                waiters.removeFirst().resume(returning: request)
            }
        }

        func nextRequest() async -> ErrorLogRequest {
            if !pending.isEmpty {
                return pending.removeFirst()
            }
            return await withCheckedContinuation { waiters.append($0) }
        }
    }

    private struct MockDeviceInfoBuilder: DeviceInfoBuilderProtocol {
        var sdkId = "ios_swift"

        func build() async -> DeviceInfo {
            DeviceInfo(
                sdkId: sdkId,
                sdkVersion: "9.9.9",
                appId: "test.app",
                appVersion: "1.0",
                deviceId: "device-1",
                deviceType: "iPhone",
                deviceModel: "iPhone17,1",
                system: "iOS",
                systemVersion: "26.0",
                timeZone: "+00:00"
            )
        }
    }

    private struct DummyError: Error {}

    private func makeLogger(sdkId: String = "ios_swift") -> (logger: ErrorLogger, service: MockErrorLoggingService) {
        let service = MockErrorLoggingService()
        let logger = ErrorLogger(
            errorLoggingService: service,
            deviceInfoBuilder: MockDeviceInfoBuilder(sdkId: sdkId)
        )
        return (logger, service)
    }

    // MARK: - errorLocation

    @Test("SDK-source errors report the framework as errorLocation instead of null")
    func sdkErrorCarriesFrameworkLocation() async {
        let (logger, service) = makeLogger()
        logger.postError(DummyError())
        let request = await service.nextRequest()
        #expect(request.errorSource == "sdk")
        #expect(request.errorLocation == "ios_swift")
        #expect(request.errorCode == nil)
    }

    @Test("errorLocation follows the configured framework for wrapper SDKs")
    func sdkErrorLocationFollowsConfiguredFramework() async {
        let (logger, service) = makeLogger(sdkId: "flutter")
        logger.postError(SahhaError(message: "boom"))
        let request = await service.nextRequest()
        #expect(request.errorSource == "sdk")
        #expect(request.errorLocation == "flutter")
    }

    @Test("API errors keep the server-reported location")
    func apiErrorKeepsServerLocation() async {
        let (logger, service) = makeLogger()
        let apiError = APIErrorResponse(title: "Bad Request", statusCode: 400, location: "api/v1/profile/score", errors: [])
        logger.postError(apiError)
        let request = await service.nextRequest()
        #expect(request.errorSource == "api")
        #expect(request.errorCode == 400)
        #expect(request.errorLocation == "api/v1/profile/score")
    }

    // MARK: - Throw-site origin

    @Test("SahhaError reports its throw site, not the logging call site")
    func sahhaErrorReportsThrowSite() async {
        let (logger, service) = makeLogger()
        let thrown = makeThrowSiteError()
        // Simulates the forwarding path: the logError call-site values must lose to the
        // origin the error captured when it was created.
        logger.postError(thrown.error, file: "Sahha/SahhaActor.swift", function: "logError(_:)", line: 242)
        let request = await service.nextRequest()
        let expectedFile: String = #fileID
        #expect(request.codePath == expectedFile)
        #expect(request.codeMethod == thrown.function)
        #expect(request.codeBody == "line \(thrown.line)")
        #expect(request.errorMessage == "Sensor set cannot be empty.")
    }

    @Test("A SahhaError wrapping an API failure keeps API code and location with the throw-site origin")
    func wrappedAPIErrorKeepsStatusAndThrowSite() async {
        let (logger, service) = makeLogger()
        let apiError = APIErrorResponse(
            title: "Unauthorized",
            statusCode: 401,
            location: "api/v1/oauth/refresh",
            errors: [.init(origin: "server", errors: ["expired token"])]
        )
        let thrown = makeSessionExpiredError(wrapping: apiError)
        logger.postError(thrown.error, file: "Sahha/SahhaActor.swift", function: "logError(_:)", line: 242)
        let request = await service.nextRequest()
        #expect(request.errorSource == "api")
        #expect(request.errorCode == 401)
        #expect(request.errorLocation == "api/v1/oauth/refresh")
        #expect(request.errorMessage == "Unauthorized")
        let expectedFile: String = #fileID
        #expect(request.codePath == expectedFile)
        #expect(request.codeMethod == thrown.function)
        #expect(request.codeBody == "line \(thrown.line)")
    }

    @Test("Nested SahhaErrors report the innermost throw site")
    func nestedSahhaErrorReportsInnermostThrowSite() async {
        let (logger, service) = makeLogger()
        let inner = makeInnerError()
        let outer = SahhaError(message: "Token store has been disposed.", error: inner.error)
        logger.postError(outer)
        let request = await service.nextRequest()
        #expect(request.codeMethod == inner.function)
        #expect(request.codeBody == "line \(inner.line)")
        #expect(request.errorMessage == "Keychain read failed.")
    }

    @Test("Errors without a captured origin fall back to the forwarded call site")
    func plainErrorUsesForwardedCallSite() async {
        let (logger, service) = makeLogger()
        logger.postError(
            DummyError(),
            file: "Sahha/Sahha.swift",
            function: "getScores(types:startDateTime:endDateTime:callback:)",
            line: 327
        )
        let request = await service.nextRequest()
        #expect(request.codePath == "Sahha/Sahha.swift")
        #expect(request.codeMethod == "getScores(types:startDateTime:endDateTime:callback:)")
        #expect(request.codeBody == "line 327")
    }
}

/// SahhaError's origin capture and `from(_:)` conversion behavior.
@Suite("SahhaError origin capture")
struct SahhaErrorOriginTests {

    private struct DummyError: Error {}

    @Test("from(_:) preserves the origin of an existing SahhaError")
    func fromPreservesExistingOrigin() {
        let thrown = makeThrowSiteError()
        let converted = SahhaError.from(thrown.error)
        #expect(converted.function == thrown.function)
        #expect(converted.line == thrown.line)
        let expectedFile: String = #fileID
        #expect(converted.file == expectedFile)
    }

    @Test("from(_:) captures the conversion site for foreign errors")
    func fromCapturesCallSiteForForeignErrors() {
        let line = UInt(#line) + 1
        let converted = SahhaError.from(DummyError())
        #expect(converted.line == line)
        let expectedFile: String = #fileID
        #expect(converted.file == expectedFile)
    }

    @Test("from(_:) keeps the readable message mapping for API errors")
    func fromMapsAPIErrorMessage() {
        let apiError = APIErrorResponse(
            title: "Bad Request",
            statusCode: 400,
            location: "api/v1/x",
            errors: [.init(origin: "field", errors: ["is required"])]
        )
        #expect(SahhaError.from(apiError).message == "Bad Request: is required")
    }

    @Test("from(_:) keeps the readable message mapping for HealthKit errors")
    func fromMapsHealthKitErrorMessage() {
        let hkError = NSError(domain: HKErrorDomain, code: HKError.Code.errorAuthorizationDenied.rawValue)
        #expect(SahhaError.from(hkError).message == "Health permissions have not been granted.")
    }
}
