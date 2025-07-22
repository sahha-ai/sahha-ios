import Foundation

extension Sequence {
    /// Applies an async transform to each element in sequence, in order.
    /// - Parameter transform: an async (and throwable) mapping closure.
    /// - Returns: an array of transformed results.
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var results: [T] = []
        results.reserveCapacity(underestimatedCount)
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}

extension Sequence {
    /// Applies an async transform to each element in sequence, in order,
    /// dropping any `nil` results.
    func asyncCompactMap<T>(
        _ transform: (Element) async throws -> T?
    ) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            if let mapped = try await transform(element) {
                results.append(mapped)
            }
        }
        return results
    }
}
