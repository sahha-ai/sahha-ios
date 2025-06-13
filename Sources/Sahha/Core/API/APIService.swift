import Foundation

protocol APIServiceProtocol: Actor {
    func send(_ endpoint: ApiEndpoint) async throws
    func send<T: Decodable>(_ endpoint: ApiEndpoint, as: T.Type) async throws -> T
}

enum APIError: Error, LocalizedError {
    case invalidURL(url: String)
    case unauthorized
    case decodingFailed(Error)
    case requestConstructionFailed(Error)
    case invalidResponse
    case api(status: Int)
    case apiResponse(ApiErrorResponse)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .unauthorized:
            return "Unauthorized"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .requestConstructionFailed(let error):
            return "Failed to construct request: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid or non-HTTP response received"
        case .api(let status):
            return "API error with status code: \(status)"
        case .apiResponse(let response):
            return "API error: \(response.title)"
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct ApiErrorResponse: Codable {
    struct Error: Codable {
        var origin: String
        var errors: [String]
    }
    var title: String
    var statusCode: Int
    var location: String
    var errors: [Error]
}

struct EmptyResponse: Decodable {}

actor APIService: APIServiceProtocol {
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(baseURL: String, session: URLSession = .shared, decoder: JSONDecoder = .init()) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }
    
    func send(_ endpoint: any ApiEndpoint) async throws {
        let request = try await buildRequest(endpoint)
        let response = try await performRequest(request, decodeTo: EmptyResponse.self)
    }
    
    func send<T: Decodable>(_ endpoint: any ApiEndpoint, as type: T.Type) async throws -> T {
        let request = try await buildRequest(endpoint)
        return try await performRequest(request, decodeTo: type)
    }
    
    private func buildRequest(_ endpoint: any ApiEndpoint) async throws -> URLRequest {
        do {
            let fullURLString = baseURL + "/" + endpoint.path
            guard var components = URLComponents(string: fullURLString) else {
                throw APIError.invalidURL(url: fullURLString)
            }
            
            components.queryItems = endpoint.queryItems
            guard let url = components.url else {
                throw APIError.invalidURL(url: fullURLString)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = endpoint.method.rawValue
            request.httpBody = endpoint.body
            
            var headers: [String: String] = ["Content-Type": "application/json"]
            if let customHeaders = endpoint.headers {
                for (key, value) in customHeaders {
                    headers[key] = value
                }
            }
            request.allHTTPHeaderFields = headers
            
            return request
        } catch {
            throw APIError.requestConstructionFailed(error)
        }
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest, decodeTo type: T.Type) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200..<300:
                if data.isEmpty, T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    return decoded
                } catch {
                    throw APIError.decodingFailed(error)
                }
            case 401:
                throw APIError.unauthorized
            default:
                if let error = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) {
                    throw APIError.apiResponse(error)
                } else {
                    throw APIError.api(status: httpResponse.statusCode)
                }
            }
        } catch {
            throw APIError.network(error)
        }
    }
}
