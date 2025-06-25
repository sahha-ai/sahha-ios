import Foundation

final class APIService: APIServiceProtocol {
    private let baseURL: String
    private let session: URLSession
    private let interceptors = InterceptorsActor()

    init(baseURL: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func registerInterceptor(_ interceptor: APIInterceptor) async {
        await interceptors.addInterceptor(interceptor)
    }

    private func applyInterceptors(to request: APIRequest) async throws -> APIRequest {
        var modifiedRequest = request
        for interceptor in await interceptors.getInterceptors() {
            modifiedRequest = try await interceptor.intercept(modifiedRequest)
        }
        return modifiedRequest
    }

    func request(_ request: APIRequest) async throws {
        let modifiedRequest = try await applyInterceptors(to: request)
        let _ = try await performRequest(modifiedRequest)
    }

    func request<T: Decodable>(_ request: APIRequest) async throws -> T {
        let modifiedRequest = try await applyInterceptors(to: request)
        let data = try await performRequest(modifiedRequest)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func performRequest(_ request: APIRequest) async throws -> Data {
        let urlRequest = try buildURLRequest(from: request)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            if httpResponse.statusCode == 204 {
                throw APIError.noContent
            }
            return data
        default:
            do {
                let apiErrorResponse = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.apiError(apiErrorResponse)
            } catch {
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        }
    }

    private func buildURLRequest(from request: APIRequest) throws -> URLRequest {
        guard let baseURL = URL(string: self.baseURL) else {
            throw APIError.invalidURL
        }

        let url = baseURL.appendingPathComponent(request.endpoint)
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = request.queryParameters

        guard let finalURL = urlComponents?.url else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = request.method.rawValue

        var headers: [String: String] = ["Content-Type": "application/json"]
        if let customHeaders = request.headers {
            for (key, value) in customHeaders {
                headers[key] = value
            }
        }
        urlRequest.allHTTPHeaderFields = headers

        if let body = request.body {
            urlRequest.httpBody = body
        }

        return urlRequest
    }
}

private actor InterceptorsActor {
    private var interceptors: [APIInterceptor] = []

    func addInterceptor(_ interceptor: APIInterceptor) {
        interceptors.append(interceptor)
    }
    
    func getInterceptors() -> [APIInterceptor] {
        interceptors
    }
}
