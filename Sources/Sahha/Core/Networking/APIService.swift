import Foundation

protocol APIService: Sendable, Interceptable {
    func send(_ request: APIRequest) async throws
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
}

final class APISerivceImpl: APIService {
    private let session: URLSession
    private let baseURL: URL
    private let interceptors = InterceptorStore()
    
    init(session: URLSession = .shared, environment: SahhaEnvironment) throws {
        guard let baseURL = URL(string: environment.baseURL) else {
            throw APIError.invalidURL
        }
        self.session = session
        self.baseURL = baseURL
    }
    
    func registerInterceptor(_ interceptor: Interceptor) async {
        await interceptors.append(interceptor)
    }
    
    func send(_ request: APIRequest) async throws {
        _ = try await executePipeline(request: request)
    }
 
    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        let response = try await executePipeline(request: request)
        do {
            return try JSONDecoder().decode(T.self, from: response.data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
    
    private func buildURLRequest(from request: APIRequest) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(request.endpoint)
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = request.queryParameters

        guard let finalURL = urlComponents?.url else {
            throw APIError.invalidURL
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
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            if httpResponse.statusCode == 204 {
                throw APIError.noContent
            }
            return APIResponse(data: data, response: httpResponse)
        default:
            do {
                let apiErrorResponse = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.apiError(apiErrorResponse)
            } catch {
                throw APIError.serverError(status: httpResponse.statusCode)
            }
        }
    }
    
    private func executePipeline(request: APIRequest) async throws -> APIResponse {
        let list = await interceptors.snapshot()
        let next = buildNext(interceptors: list.reversed())
        return try await next(request)
    }

    private func buildNext(interceptors: [Interceptor]) -> NextAPIRequest {
        var currentNext: NextAPIRequest = { request in
            try await self.performRequest(request)
        }
        for interceptor in interceptors {
            let nextCopy = currentNext
            currentNext = { request in
                try await interceptor.intercept(request: request, next: nextCopy)
            }
        }
        return currentNext
    }
}

private final actor InterceptorStore {
    private var storage: [Interceptor] = []
    
    func append(_ interceptor: Interceptor) {
        storage.append(interceptor)
    }
    
    func snapshot() -> [Interceptor] {
        storage
    }
}




