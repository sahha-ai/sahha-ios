import Foundation

struct GetDemographicEndpoint: APIEndpoint {
    var path: String { "v1/profile/demographic" }
    var method: HTTPMethod { .GET }
    var queryParameters: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { nil }
}
