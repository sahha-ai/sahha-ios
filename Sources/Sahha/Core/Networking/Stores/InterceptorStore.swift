protocol InterceptorStore: Actor {    
    func add(_ interceptor: some Interceptor)
    func get() -> [any Interceptor]
}
