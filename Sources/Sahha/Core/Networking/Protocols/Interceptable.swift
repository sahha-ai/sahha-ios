protocol Interceptable: AnyObject {
    func registerInterceptor(_ interceptor: some Intercepting) async
}
