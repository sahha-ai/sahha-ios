import Foundation

protocol APIServiceProtocol: Sendable, Disposable {
    func send(_ endpoint: ApiEndpoint) async -> Result<Void, SahhaError>
    func send<T: Decodable>(_ endpoint: ApiEndpoint, as type: T.Type) async -> Result<T, SahhaError>
}

final class APIService: APIServiceProtocol {
    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(baseURL: String, session: URLSession = .shared, decoder: JSONDecoder = .init()) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }
    
    func send(_ endpoint: any ApiEndpoint) async -> Result<Void, SahhaError> {
        return .success(())
    }
    
    func send<T: Decodable>(_ endpoint: any ApiEndpoint, as type: T.Type) async -> Result<T, SahhaError> {
        fatalError("Not implemented")
    }
    
    func dispose() {
        session.invalidateAndCancel()
        print("APIService disposed")
    }
}
