import Foundation

final actor APIClient: APIClientProviding {
    private let baseURL: URL
    private let session: URLSession
    private var interceptors: [Intercepting] = []

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func send(_ request: APIRequest) async throws {
        _ = try await executePipeline(request: request)
    }

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        let (data, response) = try await executePipeline(request: request)

        if response.statusCode == 204 || data.isEmpty {
            throw NetworkingError.noContentForType(String(describing: T.self))
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkingError.decodingError(error)
        }
    }

    func registerInterceptor(_ interceptor: some Intercepting) {
        interceptors.append(interceptor)
    }

    private func executePipeline(request: APIRequest) async throws -> APIResponse {
        let next = buildNext(from: interceptors)
        return try await next(request)
    }

    private func buildNext(from chain: [any Intercepting]) -> NextAPIRequest {
        var current: NextAPIRequest = { try await self.performRequest($0) }

        for interceptor in chain {
            let next = current
            current = { request in
                try await interceptor.intercept(request: request, next: next)
            }
        }
        return current
    }

    private func buildURLRequest(from request: APIRequest) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(request.endpoint), resolvingAgainstBaseURL: true) else {
            throw NetworkingError.invalidURL(request.endpoint)
        }
        components.queryItems = request.queryParameters

        guard let url = components.url else {
            throw NetworkingError.invalidURL(request.endpoint)
        }

        // Build URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        // Custom headers
        var headers: [String: String] = ["Content-Type": "application/json"]
        headers.merge(request.headers ?? [:]) { $1 }
        urlRequest.allHTTPHeaderFields = headers

        return urlRequest
    }

    private func performRequest(_ request: APIRequest) async throws -> APIResponse {
        let urlRequest = try buildURLRequest(from: request)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkingError.requestFailed(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            return APIResponse(data, httpResponse)
        default:
            do {
                let error = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw NetworkingError.apiError(error)
            } catch {
                throw NetworkingError.invalidStatusCode(httpResponse.statusCode)
            }
        }
    }
}
