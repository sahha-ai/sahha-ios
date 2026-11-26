import Testing
import Foundation
@testable import Sahha

// MARK: - Test transport

/// Replies to every request with one scripted status and body, and records the
/// method + path of each request so tests can assert what reached the wire.
private final class ScriptedTransport: @unchecked Sendable {
    private let lock = NSLock()
    private var status: Int = 200
    private var body = Data()
    private var recorded: [String] = []

    func reply(status: Int, body: String = "") {
        lock.lock(); defer { lock.unlock() }
        self.status = status
        self.body = Data(body.utf8)
    }

    func record(_ request: URLRequest) -> (Int, Data) {
        lock.lock(); defer { lock.unlock() }
        recorded.append("\(request.httpMethod ?? "?") \(request.url?.path ?? "")")
        return (status, body)
    }

    var requests: [String] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }
}

private final class ScriptedURLProtocol: URLProtocol {
    nonisolated(unsafe) static var transport: ScriptedTransport?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, body) = ScriptedURLProtocol.transport?.record(request) ?? (500, Data())
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://api.sahha.ai")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !body.isEmpty {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeClient(_ transport: ScriptedTransport) -> APIClient {
    ScriptedURLProtocol.transport = transport
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ScriptedURLProtocol.self]
    return APIClient(
        baseURL: URL(string: "https://api.sahha.ai/api")!,
        session: URLSession(configuration: config)
    )
}

private let demographicRequest = APIRequest(endpoint: APIEndpoints.demographic, requiresAuth: true)

// MARK: - Tests

/// A profile with no demographic stored yet answers GET demographic with 204.
/// The SDK used to throw "No Content" for it, which surfaced as an error on every
/// `getDemographic` call and stopped `syncDemographic` before it could backfill
/// gender and birth date from HealthKit.
@Suite("Demographic no-content handling", .serialized)
struct DemographicNoContentTests {

    @Test("Typed send still throws No Content on 204 for endpoints that need a body")
    func typedSendThrowsOnNoContent() async throws {
        let transport = ScriptedTransport()
        transport.reply(status: 204)
        let client = makeClient(transport)

        await #expect(throws: APIErrorResponse.self) {
            let _: SahhaDemographic = try await client.send(demographicRequest)
        }
    }

    @Test("sendOptional returns nil on 204")
    func sendOptionalNilOn204() async throws {
        let transport = ScriptedTransport()
        transport.reply(status: 204)
        let client = makeClient(transport)

        let value: SahhaDemographic? = try await client.sendOptional(demographicRequest)
        #expect(value == nil)
    }

    @Test("sendOptional returns nil on an empty 200 body")
    func sendOptionalNilOnEmpty200() async throws {
        let transport = ScriptedTransport()
        transport.reply(status: 200, body: "")
        let client = makeClient(transport)

        let value: SahhaDemographic? = try await client.sendOptional(demographicRequest)
        #expect(value == nil)
    }

    @Test("sendOptional decodes a 200 body")
    func sendOptionalDecodesBody() async throws {
        let transport = ScriptedTransport()
        transport.reply(status: 200, body: #"{"gender":"female","birthDate":"1990-01-01"}"#)
        let client = makeClient(transport)

        let value: SahhaDemographic? = try await client.sendOptional(demographicRequest)
        #expect(value == SahhaDemographic(gender: "female", birthDate: "1990-01-01"))
    }

    @Test("sendOptional still throws on an error status")
    func sendOptionalThrowsOnErrorStatus() async throws {
        let transport = ScriptedTransport()
        transport.reply(status: 500, body: "boom")
        let client = makeClient(transport)

        await #expect(throws: APIErrorResponse.self) {
            let _: SahhaDemographic? = try await client.sendOptional(demographicRequest)
        }
    }

    @Test("DemographicService maps 204 to an empty demographic")
    func serviceMaps204ToEmpty() async throws {
        let transport = ScriptedTransport()
        transport.reply(status: 204)
        let service = DemographicService(apiClient: makeClient(transport))

        let demographic = try await service.getDemographic()
        #expect(demographic == SahhaDemographic())
        #expect(demographic.isEmpty)
    }

    @Test("Public getDemographic value is nil, not an empty demographic, on 204 (Android parity)")
    func publicValueIsNilOn204() async throws {
        let transport = ScriptedTransport()
        transport.reply(status: 204)
        let service = DemographicService(apiClient: makeClient(transport))

        #expect(try await service.getDemographic().nilIfEmpty == nil)
    }

    @Test("Public getDemographic value keeps a partly filled demographic")
    func publicValueKeepsPartialDemographic() {
        #expect(SahhaDemographic(gender: "female").nilIfEmpty == SahhaDemographic(gender: "female"))
        #expect(SahhaDemographic(birthDate: "1990-01-01").nilIfEmpty == SahhaDemographic(birthDate: "1990-01-01"))
    }

    @Test("Manager on 204: returns empty, caches it, and the HealthKit backfill PATCHes")
    func managerBackfillsAfterNoContent() async throws {
        let transport = ScriptedTransport()
        transport.reply(status: 204)
        let manager = DemographicManager(
            demographicService: DemographicService(apiClient: makeClient(transport)),
            cache: DemographicCache(
                key: "test.demographic",
                storage: MockKeychainStorage(),
                logger: NoopErrorLogger()
            ),
            logger: NoopErrorLogger()
        )

        // The syncDemographic flow: read the server copy, merge HealthKit, update.
        var demographic = try await manager.getDemographic()
        #expect(demographic.isEmpty)

        // The empty answer is cached, so a second read does not refetch.
        _ = try await manager.getDemographic()
        #expect(transport.requests == ["GET /api/v1/profile/demographic"])

        demographic.mergeWith(SahhaDemographic(gender: "female", birthDate: "1990-01-01"))
        transport.reply(status: 200)
        try await manager.updateDemographic(demographic)

        #expect(transport.requests.last == "PATCH /api/v1/profile/demographic")
        #expect(try await manager.getDemographic() == SahhaDemographic(gender: "female", birthDate: "1990-01-01"))
    }
}
