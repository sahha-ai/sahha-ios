import Foundation

struct ConcurrentBatchProcessor {
    /// Runs a process on batches of input, with limited concurrency.
    /// - Parameters:
    ///   - items: The collection to batch and process.
    ///   - batchSize: Number of items per batch.
    ///   - maxConcurrentBatches: Maximum concurrent batch tasks.
    ///   - process: Async closure processing a batch.
    /// - Returns: Flattened array of results.
    static func run<Input: Sendable, Output: Sendable>(
        items: [Input],
        batchSize: Int,
        maxConcurrentBatches: Int,
        process: @escaping @Sendable ([Input]) async -> [Output]
    ) async -> [Output] {
        let semaphore = AsyncSemaphore(value: maxConcurrentBatches)
        let batches = items.chunked(into: batchSize)
        return await withTaskGroup(of: [Output].self) { group in
            for batch in batches {
                await semaphore.wait()
                group.addTask {
                    defer { Task { await semaphore.signal() } }
                    return await process(batch)
                }
            }
            return await group.reduce(into: [Output]()) { $0 += $1 }
        }
    }

    /// Runs a process on batches of input, with limited concurrency.
    /// - Parameters:
    ///   - items: The collection to batch and process.
    ///   - batchSize: Number of items per batch.
    ///   - maxConcurrentBatches: Maximum concurrent batch tasks.
    ///   - process: Async closure processing a batch.
    /// - Returns: Flattened array of results.
    /// - Throws: Rethrows the first error encountered from any batch.
    static func runThrowing<Input: Sendable, Output: Sendable>(
        items: [Input],
        batchSize: Int,
        maxConcurrentBatches: Int,
        process: @escaping @Sendable ([Input]) async throws -> [Output]
    ) async throws -> [Output] {
        let semaphore = AsyncSemaphore(value: maxConcurrentBatches)
        let batches = items.chunked(into: batchSize)
        return try await withThrowingTaskGroup(of: [Output].self) { group in
            for batch in batches {
                await semaphore.wait()
                group.addTask {
                    defer { Task { await semaphore.signal() } }
                    return try await process(batch)
                }
            }
            return try await group.reduce(into: [Output]()) { $0 += $1 }
        }
    }
}
