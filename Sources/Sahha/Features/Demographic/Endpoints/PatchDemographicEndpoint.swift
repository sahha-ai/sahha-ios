import Foundation

struct PatchDemographicEndpoint: APIEndpoint {
    let request: DemographicRequest

    var path: String { "v1/profile/demographic" }
    var method: HTTPMethod { .PATCH }
    var queryParameters: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { encodeBody(request) }
}
