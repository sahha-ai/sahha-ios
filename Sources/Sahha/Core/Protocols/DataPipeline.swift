protocol DataPipeline: Actor {
    associatedtype Input: Sendable
    func processData(_ input: Input) async throws
    func isAcceptingData() async -> Bool
}
