import Foundation

struct NormalisingEngine<Input, Output>: @unchecked Sendable {
    typealias Normaliser = @Sendable (Input) -> [Output]

    private let keyPath: KeyPath<Input, String>
    private let table: [String: Normaliser]
    private let fallback: Normaliser

    init(
        key: KeyPath<Input, String>,
        table: [String: Normaliser],
        fallback: @escaping Normaliser
    ) {
        self.keyPath = key
        self.table = table
        self.fallback = fallback
    }

    @inline(__always)
    func normalise(_ value: Input) -> [Output] {
        let key = value[keyPath: keyPath]
        let handler = table[key] ?? fallback
        return handler(value)
    }
}
