import Foundation

struct GetBiomarkersEndpoint: ApiEndpoint {
    let categories: Set<String>
    let types: Set<String>
    let startDateTime: Date
    let endDateTime: Date

    var path: String { "v2/biomarker" }
    var method: HTTPMethod { .GET }

    var queryItems: [URLQueryItem]? {
        var items = [URLQueryItem]()
        
        categories.forEach { category in
            items.append(URLQueryItem(name: "categories", value: category))
        }
        types.forEach { type in
            items.append(URLQueryItem(name: "types", value: type))
        }
        items.append(URLQueryItem(name: "startDateTime", value: startDateTime.isoDate))
        items.append(URLQueryItem(name: "endDateTime", value: endDateTime.isoDate))
        
        return items
    }

    var headers: [String : String]? { nil }
    var body: Data? { nil }
}
