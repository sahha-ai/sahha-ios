import Foundation

final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let interceptorStore: APIInterceptorStoreProtocol?

    init(baseURL: URL, session: URLSession = .shared, interceptorStore: APIInterceptorStoreProtocol? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.interceptorStore = interceptorStore
    }

    func send(_ request: APIRequest) async throws {
        _ = try await executePipeline(request: request)
    }

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        let (data, response) = try await executePipeline(request: request)

        if response.statusCode == 204 || data.isEmpty {
            throw APIErrorResponse(
                title: "No Content",
                statusCode: 204,
                location: "APIClient.send",
                errors: [.init(origin: "Decoding", errors: ["No content for type \(T.self)"])]
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIErrorResponse(
                title: "Decoding Error",
                statusCode: response.statusCode,
                location: "APIClient.send",
                errors: [.init(origin: "Decoding", errors: [error.localizedDescription])]
            )
        }
    }

    private func executePipeline(request: APIRequest) async throws -> APIResponse {
        let interceptors = await interceptorStore?.getInterceptors() ?? []
        let next = buildNext(from: interceptors)
        return try await next(request)
    }

    private func buildNext(from chain: [any APIInterceptorProtocol]) -> NextAPIRequest {
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
            throw APIErrorResponse(
                title: "Invalid URL",
                statusCode: -1,
                location: "APIClient.buildURLRequest",
                errors: [.init(origin: "URL", errors: ["Invalid endpoint: \(request.endpoint)"])]
            )
        }
        components.queryItems = request.queryParameters

        guard let url = components.url else {
            throw APIErrorResponse(
                title: "Invalid URL",
                statusCode: -1,
                location: "APIClient.buildURLRequest",
                errors: [.init(origin: "URL", errors: ["Invalid endpoint: \(request.endpoint)"])]
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        var headers: [String: String] = ["Content-Type": "application/json"]
        headers.merge(request.headers ?? [:]) { $1 }
        urlRequest.allHTTPHeaderFields = headers

        return urlRequest
    }

    private func performRequest(_ request: APIRequest) async throws -> APIResponse {
        let urlRequest: URLRequest
        do {
            urlRequest = try buildURLRequest(from: request)
        } catch let apiError as APIErrorResponse {
            throw apiError
        } catch {
            throw APIErrorResponse(
                title: "Request Building Error",
                statusCode: -1,
                location: "APIClient.performRequest",
                errors: [.init(origin: "Request Building", errors: [error.localizedDescription])]
            )
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIErrorResponse(
                title: "Request Failed",
                statusCode: -1,
                location: "APIClient.performRequest",
                errors: [.init(origin: "Network", errors: [error.localizedDescription])]
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIErrorResponse(
                title: "Invalid Response",
                statusCode: -1,
                location: "APIClient.performRequest",
                errors: [.init(origin: "Network", errors: ["No HTTPURLResponse"])]
            )
        }

        switch httpResponse.statusCode {
        case 200...299:
            return APIResponse(data, httpResponse)
        default:
            do {
                let apiError = try JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw apiError
            } catch {
                print(request.endpoint)
                print(error)
                // DEBUG: Print raw JSON for investigation
                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    print("DEBUG Raw error response:", jsonObject)
                } catch {
                    print("DEBUG Could not parse response as JSON.")
                }
                throw APIErrorResponse(
                    title: "HTTP Error",
                    statusCode: httpResponse.statusCode,
                    location: "APIClient.performRequest",
                    errors: [.init(origin: "HTTP", errors: ["HTTP error with status code \(httpResponse.statusCode)"])]
                )
            }
        }
    }
}
