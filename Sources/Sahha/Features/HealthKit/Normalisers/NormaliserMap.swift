import Foundation

protocol NormaliserRegistry {
    associatedtype Input
    associatedtype Output

    static var normaliser: Normaliser<Input, Output> { get }
}

struct Normaliser<Input, Output>: @unchecked Sendable {
    typealias NormaliserFn = @Sendable (Input) -> [Output]

    private let keyPath: KeyPath<Input, String>
    private let registry: [String: NormaliserFn]
    private let fallback: NormaliserFn

    init(
        key: KeyPath<Input, String>,
        registry: [String: NormaliserFn],
        fallback: @escaping NormaliserFn
    ) {
        self.keyPath = key
        self.registry = registry
        self.fallback = fallback
    }

    @inline(__always)
    func normalise(_ value: Input) -> [Output] {
        let key = value[keyPath: keyPath]
        let handler = registry[key] ?? fallback
        return handler(value)
    }
}

