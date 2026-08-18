import Testing
import Foundation
@testable import Sahha

/// The error logger's synchronous dedup gate (PRD #76, D5): one post per resolved
/// origin per logger instance, a hard cap on distinct origins, and a cap notice
/// recorded exactly once so a capped process is distinguishable from a quiet one.
@Suite("ErrorLogger dedup")
struct ErrorLoggerDedupTests {

    // MARK: - Test doubles

    /// Records posted requests and lets tests await a target arrival count.
    private actor CountingErrorLoggingService: ErrorLoggingServiceProtocol {
        private(set) var requests: [ErrorLogRequest] = []
        private var waiters: [(target: Int, continuation: CheckedContinuation<Void, Never>)] = []

        func postError(_ request: ErrorLogRequest) async throws {
            requests.append(request)
            let reached = requests.count
            let ready = waiters.filter { $0.target <= reached }
            waiters.removeAll { $0.target <= reached }
            for waiter in ready { waiter.continuation.resume() }
        }

        func waitForCount(_ target: Int) async {
            if requests.count >= target { return }
            await withCheckedContinuation { continuation in
                waiters.append((target, continuation))
            }
        }
    }

    private struct StubDeviceInfoBuilder: DeviceInfoBuilderProtocol {
        func build() async -> DeviceInfo {
            DeviceInfo(
                sdkId: "ios_swift",
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

    private func makeLogger() -> (logger: ErrorLogger, service: CountingErrorLoggingService) {
        let service = CountingErrorLoggingService()
        let logger = ErrorLogger(errorLoggingService: service, deviceInfoBuilder: StubDeviceInfoBuilder())
        return (logger, service)
    }

    /// Errors whose resolved origin is fully controlled: the captured throw site varies
    /// only by the given line, so tests can mint identical or distinct origins at will.
    private func fixtureError(line: UInt, message: String = "fixture failure") -> SahhaError {
        SahhaError(message: message, file: "Sahha/DedupFixture.swift", function: "fixture()", line: line)
    }

    /// Gives already-spawned posting tasks scheduler time, so exact-count assertions
    /// would observe a duplicate leaked by a broken gate.
    private func settle() async {
        for _ in 0..<25 { await Task.yield() }
    }

    // MARK: - Tests

    @Test("An identical resolved origin is posted once, regardless of call site or message")
    func identicalOriginPostsOnce() async {
        let (logger, service) = makeLogger()
        let error = fixtureError(line: 10)

        // Two different forwarding call sites, one captured throw site.
        logger.postError(error, file: "Sahha/SahhaActor.swift", function: "logError(_:)", line: 261)
        logger.postError(error, file: "Sahha/HealthKitManager.swift", function: "resumeSensors()", line: 99)
        // A different message from the same origin is still the same signature.
        logger.postError(fixtureError(line: 10, message: "another message"))
        // A different origin passes the gate.
        logger.postError(fixtureError(line: 11))

        await service.waitForCount(2)
        await settle()
        let requests = await service.requests
        #expect(requests.count == 2)
        #expect(Set(requests.compactMap(\.codeBody)) == ["line 10", "line 11"])
    }

    @Test("The gate is synchronous: a concurrent burst of one origin posts once")
    func concurrentBurstPostsOnce() async {
        let (logger, service) = makeLogger()
        let error = fixtureError(line: 20)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<32 {
                group.addTask { logger.postError(error) }
            }
        }

        await service.waitForCount(1)
        await settle()
        let requests = await service.requests
        #expect(requests.count == 1)
        #expect(requests.first?.codeBody == "line 20")
    }

    @Test("The gate keys on the same resolved origin the payload reports")
    func gateAndPayloadAgree() async {
        let (logger, service) = makeLogger()
        // Different wrappers around one inner throw site: the innermost SahhaError
        // is the resolved origin for the payload, so it must be for the gate too.
        let inner = fixtureError(line: 40)
        logger.postError(SahhaError(message: "wrapper A", error: inner))
        logger.postError(SahhaError(message: "wrapper B", error: inner))

        await service.waitForCount(1)
        await settle()
        let requests = await service.requests
        #expect(requests.count == 1)
        #expect(requests.first?.codePath == "Sahha/DedupFixture.swift")
        #expect(requests.first?.codeMethod == "fixture()")
        #expect(requests.first?.codeBody == "line 40")
    }

    @Test("The distinct-origin cap is enforced and the cap notice is recorded exactly once")
    func capIsEnforcedAndRecordedOnce() async {
        let (logger, service) = makeLogger()
        let cap = ErrorLogger.maxDistinctOrigins
        #expect(cap >= 64)

        for i in 0..<cap {
            logger.postError(fixtureError(line: UInt(i)))
        }
        // Over the cap: two new origins — the first records the notice, the second nothing.
        logger.postError(fixtureError(line: UInt(cap)))
        logger.postError(fixtureError(line: UInt(cap + 1)))
        // A known origin over the cap stays deduped, not re-posted.
        logger.postError(fixtureError(line: 0))

        await service.waitForCount(cap + 1)
        await settle()
        let requests = await service.requests
        #expect(requests.count == cap + 1)
        let notices = requests.filter { $0.errorMessage?.contains("distinct error origins") == true }
        #expect(notices.count == 1)
    }

    @Test("Dedup state is per logger instance: a fresh logger posts the same origin again")
    func freshLoggerPostsAgain() async {
        let service = CountingErrorLoggingService()
        let first = ErrorLogger(errorLoggingService: service, deviceInfoBuilder: StubDeviceInfoBuilder())
        let second = ErrorLogger(errorLoggingService: service, deviceInfoBuilder: StubDeviceInfoBuilder())
        let error = fixtureError(line: 30)

        first.postError(error)
        first.postError(error)
        // The post-deauth world: a fresh container builds a fresh logger.
        second.postError(error)

        await service.waitForCount(2)
        await settle()
        #expect(await service.requests.count == 2)
    }

    @Test("Skipped errors never consume an origin slot")
    func skippedErrorsDoNotConsumeSlots() async {
        struct PlainFailure: Error {}
        let (logger, service) = makeLogger()

        // CancellationError is filtered before the gate, so the shared origin must
        // still be free for a real error arriving through the same call site. A gate
        // placed before the filter would mark the origin posted and drop both.
        logger.postError(CancellationError(), file: "Sahha/Forwarder.swift", function: "forward()", line: 1)
        logger.postError(PlainFailure(), file: "Sahha/Forwarder.swift", function: "forward()", line: 1)

        await service.waitForCount(1)
        await settle()
        let requests = await service.requests
        #expect(requests.count == 1)
        #expect(requests.first?.codePath == "Sahha/Forwarder.swift")
        #expect(requests.first?.codeBody == "line 1")
    }
}
