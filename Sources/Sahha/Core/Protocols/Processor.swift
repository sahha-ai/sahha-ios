protocol Processor: Actor, Sendable {
    associatedtype Input
    func process(_ inputs: [Input]) async throws
    func isAcceptingData() async -> Bool
}
