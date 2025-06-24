import Foundation

struct GetBiomarkersEndpoint: APIEndpoint {
    let categories: Set<String>
    let types: Set<String>
    let startDateTime: Date
    let endDateTime: Date

    var path: String { "v2/biomarker" }
    var method: HTTPMethod { .GET }

    var queryParameters: [URLQueryItem]? {
        var params = [URLQueryItem]()
        
        categories.forEach { category in
            params.append(URLQueryItem(name: "categories", value: category))
        }
        types.forEach { type in
            params.append(URLQueryItem(name: "types", value: type))
        }
        params.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        params.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))
        
        return params
    }

    var headers: [String : String]? { nil }
    var body: Data? { nil }
}
