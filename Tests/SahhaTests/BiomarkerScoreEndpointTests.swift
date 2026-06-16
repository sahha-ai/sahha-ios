import Testing
import Foundation
@testable import Sahha

// MARK: - Test transport

/// Captures the URLs that the mock transport was asked to load, so tests can assert the
/// exact request line (path + percent-encoding) that `APIClient` produced.
private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []

    func record(_ url: URL) {
        lock.lock(); defer { lock.unlock() }
        urls.append(url)
    }

    var lastURL: URL? {
        lock.lock(); defer { lock.unlock() }
        return urls.last
    }
}

/// Intercepts requests issued through an injected `URLSession`, records the URL, and
/// replies `200` with an empty JSON array so the decoding path completes cleanly.
private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var recorder: RequestRecorder?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url {
            MockURLProtocol.recorder?.record(url)
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://api.sahha.ai")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("[]".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeMockSession(recorder: RequestRecorder) -> URLSession {
    MockURLProtocol.recorder = recorder
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private let testBaseURL = URL(string: "https://api.sahha.ai/api")!

// A non-UTC offset (+12:00). The literal "+" must reach the wire as "%2B"; a raw "+"
// would be decoded as a space server-side and corrupt the offset.
private let startWithOffset = "2026-06-12T00:00:00.000+12:00"
private let endWithOffset = "2026-06-13T00:00:00.000+12:00"

// MARK: - Tests

@Suite(.serialized)
struct BiomarkerScoreEndpointTests {

    @Test("Biomarker request targets v1 and percent-encodes a + in the query")
    func biomarkerRequestUsesV1AndEncodesPlus() async throws {
        let recorder = RequestRecorder()
        let client = APIClient(baseURL: testBaseURL, session: makeMockSession(recorder: recorder))
        let service = BiomarkerService(apiClient: client)

        _ = try? await service.fetchBiomarkers(
            categories: [.activity],
            types: [.steps],
            startDateTime: startWithOffset,
            endDateTime: endWithOffset
        )

        let line = try #require(recorder.lastURL).absoluteString
        #expect(line.contains("/api/v1/profile/biomarker"))
        #expect(!line.contains("/api/v2/profile/biomarker"))
        // The managers no longer emit an offset, but the APIClient must still encode a
        // literal "+" as "%2B" if one ever reaches the query (servers decode raw "+" as space).
        #expect(line.contains("startDateTime=2026-06-12T00:00:00.000%2B12:00"))
        #expect(line.contains("endDateTime=2026-06-13T00:00:00.000%2B12:00"))
        #expect(!line.contains("+12:00"))
    }

    @Test("Score request targets v1 and percent-encodes a + in the query")
    func scoreRequestUsesV1AndEncodesPlus() async throws {
        let recorder = RequestRecorder()
        let client = APIClient(baseURL: testBaseURL, session: makeMockSession(recorder: recorder))
        let service = ScoreService(apiClient: client)

        _ = try? await service.fetchScores(
            types: [.wellbeing],
            startDateTime: startWithOffset,
            endDateTime: endWithOffset
        )

        let line = try #require(recorder.lastURL).absoluteString
        #expect(line.contains("/api/v1/profile/score"))
        #expect(!line.contains("/api/v2/profile/score"))
        #expect(line.contains("startDateTime=2026-06-12T00:00:00.000%2B12:00"))
        #expect(line.contains("endDateTime=2026-06-13T00:00:00.000%2B12:00"))
        #expect(!line.contains("+12:00"))
    }

    @Test("Manager forwards an offset-less ISO-8601 datetime, not a bare date")
    func managerSendsDateTimeWithoutOffset() async throws {
        let service = CapturingBiomarkerService()
        let manager = BiomarkerManager(biomarkerService: service)

        _ = try await manager.getBiomarkers(
            categories: [.activity],
            types: [.steps],
            startDateTime: Date(timeIntervalSince1970: 1_749_686_400),
            endDateTime: Date(timeIntervalSince1970: 1_749_772_800)
        )

        let start = try #require(service.startDateTime)
        // Must carry a time component but no timezone designator: getScores/getBiomarkers
        // send a local, offset-less datetime so the bounds reach the server unzoned.
        #expect(start.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}"#, options: .regularExpression) != nil)
        #expect(start.range(of: #"(Z|[+-]\d{2}:\d{2})$"#, options: .regularExpression) == nil)
        // Regression guard against the old "yyyy-MM-dd" (date-only) behaviour.
        #expect(start.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) == nil)
    }
}

// MARK: - Test double

/// Records the formatted datetime strings the manager hands to the service layer.
private final class CapturingBiomarkerService: BiomarkerServiceProtocol, @unchecked Sendable {
    private(set) var startDateTime: String?
    private(set) var endDateTime: String?

    func fetchBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDateTime: String,
        endDateTime: String
    ) async throws -> [SahhaBiomarker] {
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        return []
    }
}
