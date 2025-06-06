import Foundation

struct PatchDemographicEndpoint: ApiEndpoint {
    let request: SahhaDemographicRequest

    var path: String { "v1/profile/demographic" }
    var method: HTTPMethod { .patch }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { encodeBody(request) }
}
