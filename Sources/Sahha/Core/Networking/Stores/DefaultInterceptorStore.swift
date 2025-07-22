final actor DefaultInterceptorStore: InterceptorStore {
    private var interceptors: [AnyHashable: any Interceptor] = [:]
    
    func add(_ interceptor: some Interceptor) {
        let key = AnyHashable(interceptor.id)
        interceptors[key] = interceptor
    }
    
    func get() -> [any Interceptor] {
        interceptors.values.sorted { $0.priority > $1.priority }
    }
}
