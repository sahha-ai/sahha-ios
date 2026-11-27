import Testing
import Foundation
@testable import Sahha

/// `APIClient` builds every request as `baseURL.appendingPathComponent(endpoint)`, so a
/// base URL that Foundation cannot parse as an absolute HTTPS URL breaks *all* traffic
/// for that environment with an unsupported-URL error rather than any one endpoint.
///
/// The `.development` base URL shipped as `"https:development-api.sahha.ai/api"` — a
/// missing `//` that `URL(string:)` accepts happily, parsing it as scheme `https` with a
/// nil host and the authority swallowed into the path. These tests pin the shape so a
/// future typo fails here instead of in the field.
@Suite("SahhaEnvironment base URLs")
struct SahhaEnvironmentBaseURLTests {

    @Test("Every environment's base URL is an absolute HTTPS URL with a host")
    func everyEnvironmentHasAbsoluteHTTPSBaseURL() {
        for environment in SahhaEnvironment.allCases {
            let baseURL = environment.baseURL

            #expect(baseURL.scheme == "https", "\(environment.rawValue) base URL is not HTTPS: \(baseURL)")
            #expect(baseURL.host != nil, "\(environment.rawValue) base URL has no host: \(baseURL)")
            #expect(
                baseURL.absoluteString.hasPrefix("https://"),
                "\(environment.rawValue) base URL is missing the // after the scheme: \(baseURL)"
            )
        }
    }

    /// Pins the exact hosts too: a nil-host check alone would still pass if a base URL
    /// were pointed at the wrong (but well-formed) hostname. The `switch` is exhaustive,
    /// so adding a `SahhaEnvironment` case fails to compile until its URL is declared here.
    @Test("Each environment maps to its documented API host")
    func environmentsMapToDocumentedHosts() {
        for environment in SahhaEnvironment.allCases {
            let expected: String
            switch environment {
            case .development: expected = "https://development-api.sahha.ai/api"
            case .sandbox: expected = "https://sandbox-api.sahha.ai/api"
            case .production: expected = "https://api.sahha.ai/api"
            }

            #expect(environment.baseURL.absoluteString == expected)
        }
    }

    /// Mirrors `APIClient.buildURLRequest`: the endpoint is appended and the result is
    /// resolved through `URLComponents`. A base URL with a nil host survives both steps
    /// and only fails later inside `URLSession`, so assert the host reaches the request.
    @Test("Appending an endpoint keeps the host on the request URL")
    func appendingEndpointPreservesHost() throws {
        for environment in SahhaEnvironment.allCases {
            let endpointURL = environment.baseURL.appendingPathComponent("profile/token")
            let components = try #require(
                URLComponents(url: endpointURL, resolvingAgainstBaseURL: true),
                "\(environment.rawValue) endpoint URL could not be parsed: \(endpointURL)"
            )
            let requestURL = try #require(components.url)

            #expect(requestURL.host == environment.baseURL.host)
            #expect(requestURL.host != nil, "\(environment.rawValue) request URL has no host: \(requestURL)")
            #expect(requestURL.path == "/api/profile/token")
        }
    }
}
