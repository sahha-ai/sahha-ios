protocol Disposable: Sendable {
    func dispose() throws
}

protocol DisposableAsync: Sendable {
    func dispose() async throws
}
