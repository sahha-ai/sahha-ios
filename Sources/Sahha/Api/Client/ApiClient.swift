import Foundation

final actor ApiClient {
    static let shared = ApiClient()
    
    private init() {}
    
    func send(_ endpoint: ApiEndpoint) async -> Result<Void, SahhaError> {
        let result = await execute(endpoint, responseType: EmptyResponse.self)
        switch result {
        case .success: return .success(())
        case .failure(let error): return .failure(error)
        }
    }
    
    func send<T: Decodable>(_ endpoint: ApiEndpoint, responseType: T.Type) async -> Result<T, SahhaError> {
        let result = await execute(endpoint, responseType: responseType)
        
        if case let .failure(error) = result {
            await ApiController.postError(
                source: "api",
                code: error.code,
                location: "\(endpoint.method) \(endpoint.path)",
                message: error.description,
            )
        }
        
        return result
    }
    
    private func execute<T: Decodable>(_ endpoint: ApiEndpoint, responseType: T.Type, refreshing: Bool = false) async -> Result<T, SahhaError> {
        do {
            let baseURL = try await ApiConfiguration.baseURL()
            let fullURLString = baseURL + "/" + endpoint.path
            guard let url = URL(string: fullURLString) else {
                return .failure(.invalidURL(url: fullURLString))
            }
            
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = endpoint.queryItems
            guard let finalURL = components?.url else {
                return .failure(.custom(message: "Failed to build URL with query items."))
            }
            
            var request = URLRequest(url: finalURL)
            request.httpMethod = endpoint.method.rawValue
            request.httpBody = endpoint.body
            
            var headers: [String: String] = ["Content-Type": "application/json"]
            if let auth = await TokenStore.shared.getAuthorizationHeader() {
                headers["Authorization"] = auth
            }
            if let customHeaders = endpoint.headers {
                for (key, value) in customHeaders {
                    headers[key] = value
                }
            }
            request.allHTTPHeaderFields = headers
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.unknown)
            }
            
            switch httpResponse.statusCode {
            case 200..<300:
                if data.isEmpty, T.self == EmptyResponse.self {
                    return .success(EmptyResponse() as! T)
                }
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    return .success(decoded)
                } catch {
                    return .failure(.decodingFailed)
                }
                
            case 401 where refreshing:
                return .failure(.unauthorized)
               
            case 401:
                do {
                    try await RefreshTokenManager.shared.refreshIfNeeded()
                    return await execute(endpoint, responseType: responseType, refreshing: true)
                } catch {
                    return .failure(error as? SahhaError ?? .unauthorized)
                }
                
            default:
                if let apiError = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) {
                    return .failure(.apiError(apiError))
                } else {
                    return .failure(.serverError(statusCode: httpResponse.statusCode))
                }
            }
            
        } catch {
            return .failure(.noInternet)
        }
    }
}
