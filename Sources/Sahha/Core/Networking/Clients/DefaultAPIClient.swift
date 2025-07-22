import Foundation

final class DefaultAPIClient: APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let interceptors: InterceptorStore

    init(
        session: URLSession = .shared,
        baseURL: URL,
        interceptors: InterceptorStore = DefaultInterceptorStore()
    ) throws {
        self.session = session
        self.baseURL = baseURL
        self.interceptors = interceptors
    }
    
    func send(_ request: APIRequest) async throws {
        _ = try await executePipeline(request: request)
    }
 
    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        let response = try await executePipeline(request: request)
        do {
            return try JSONDecoder().decode(T.self, from: response.data)
        } catch {
            throw DecodingError.failed(error)
        }
    }
    
    func registerInterceptor(_ interceptor: some Interceptor) async {
        await interceptors.add(interceptor)
    }
    
    private func buildURLRequest(from request: APIRequest) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(request.endpoint)
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = request.queryParameters

        guard let finalURL = urlComponents?.url else {
            throw TransportError.invalidURL
        }

        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = request.method.rawValue

        var headers: [String: String] = ["Content-Type": "application/json"]
        headers.merge(request.headers ?? [:]) { $1 }
        urlRequest.allHTTPHeaderFields = headers

        if let body = request.body {
            urlRequest.httpBody = body
        }

        return urlRequest
    }
    
    private func performRequest(_ request: APIRequest) async throws -> APIResponse {
        let urlRequest = try buildURLRequest(from: request)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransportError.nonHTTPResponse(response)
        }

        switch httpResponse.statusCode {
        case 200...299:
            if httpResponse.statusCode == 204 {
                throw ResponseError.noContent
            }
            return APIResponse(data: data, response: httpResponse)
        default:
            do {
                let apiErrorResponse = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw ResponseError.api(apiErrorResponse)
            } catch {
                throw ResponseError.status(httpResponse.statusCode)
            }
        }
    }
    
    private func executePipeline(request: APIRequest) async throws -> APIResponse {
        let chain = await interceptors.get()
        let next = buildNext(from: chain)
        return try await next(request)
    }

    private func buildNext(from chain: [any Interceptor]) -> NextAPIRequest {
        var current: NextAPIRequest = { try await self.performRequest($0) }

        for interceptor in chain {
            let nextCopy = current
            current = { request in
                try await interceptor.intercept(request: request, next: nextCopy)
            }
        }
        return current
    }
}
