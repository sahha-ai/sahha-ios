import Foundation

struct PatchDemographicEndpoint: ApiEndpoint {
    let request: DemographicRequest

    var path: String { "v1/profile/demographic" }
    var method: HTTPMethod { .PATCH }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { encodeBody(request) }
}
