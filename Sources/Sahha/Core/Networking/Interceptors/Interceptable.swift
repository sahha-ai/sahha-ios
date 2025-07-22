protocol Interceptable: AnyObject {
    func registerInterceptor(_ interceptor: some Interceptor) async
}
