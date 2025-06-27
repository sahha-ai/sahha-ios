import Foundation

final class APIService: APIServiceProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let interceptors = InterceptorsActor()

    init(baseURL: String, session: URLSession = .shared) throws {
        guard let baseURL = URL(string: baseURL) else { throw APIError.invalidURL }
        self.baseURL = baseURL
        self.session = session
    }

    func registerInterceptor(_ interceptor: APIInterceptor) async {
        await interceptors.addInterceptor(interceptor)
    }

    func send(_ request: APIRequest) async throws {
        let interceptors = await interceptors.getInterceptors()
        let chain = APIChain(service: self, request: request, interceptors: interceptors)
        _ = try await chain.proceed()
    }

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        let interceptors = await interceptors.getInterceptors()
        let chain = APIChain(service: self, request: request, interceptors: interceptors)
        let response = try await chain.proceed()

        do {
            return try JSONDecoder().decode(T.self, from: response.data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    fileprivate func performRequest(_ request: APIRequest) async throws -> APIResponse {
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
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
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

private struct APIChain {
    private let service: APIService
    private let interceptors: [APIInterceptor]
    private let initialRequest: APIRequest

    init(service: APIService, request: APIRequest, interceptors: [APIInterceptor]) {
        self.service = service
        self.initialRequest = request
        self.interceptors = interceptors
    }

    func proceed() async throws -> APIResponse {
        let next = buildNext(interceptors: interceptors.reversed())
        return try await next(initialRequest)
    }

    private func buildNext(interceptors: [APIInterceptor]) -> NextAPIRequest {
        var currentNext: NextAPIRequest = { request in
            try await self.service.performRequest(request)
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
