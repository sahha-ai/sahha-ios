import Foundation

struct GetDemographicEndpoint: ApiEndpoint {
    var path: String { "v1/profile/demographic" }
    var method: HTTPMethod { .GET }
    var queryItems: [URLQueryItem]? { nil }
    var headers: [String : String]? { nil }
    var body: Data? { nil }
}
