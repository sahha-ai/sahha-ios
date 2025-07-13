protocol Interceptable {
    func registerInterceptor(_ interceptor: Interceptor) async
}
