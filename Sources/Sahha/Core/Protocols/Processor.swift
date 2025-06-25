protocol Processor: Sendable {
    associatedtype Input
    func process(_ inputs: [Input]) async throws
}
