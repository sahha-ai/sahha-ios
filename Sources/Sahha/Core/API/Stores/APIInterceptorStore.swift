actor APIInterceptorStore: APIInterceptorStoreProtocol {
    private var interceptors: [APIInterceptorProtocol] = []
    
    func addInterceptor(_ interceptor: any APIInterceptorProtocol) {
        interceptors.append(interceptor)
    }

    func getInterceptors() -> [any APIInterceptorProtocol] {
        interceptors
    }
}
