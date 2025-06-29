protocol AppEventManagerProtocol: LifecycleHandler, DisposableAsync {
    func start() async
}
