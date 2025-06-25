protocol Disposable: Sendable {
    func dispose()
}

protocol DisposableAsync: Sendable {
    func dispose() async
}
