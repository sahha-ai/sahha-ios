import Foundation

protocol TimeProvider: Sendable {
    func now() -> Date
}

struct SystemTime: TimeProvider {
    public init() {}
    public func now() -> Date { Date() }
}

struct FixedTime: TimeProvider {
    private let fixed: Date
    public init(_ date: Date) { self.fixed = date }
    public func now() -> Date { fixed }
}
