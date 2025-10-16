protocol APIInterceptorStoreProtocol: Actor {
    func addInterceptor(_ interceptor: APIInterceptorProtocol)
    func getInterceptors() -> [APIInterceptorProtocol]
}
