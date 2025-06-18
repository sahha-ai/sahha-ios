protocol Normaliser: Sendable {
    associatedtype Input
    associatedtype Output
    func normalise(_ input: Input) async -> Output
}
