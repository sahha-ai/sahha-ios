import Foundation

protocol BatchStorage<Item>: Actor, Disposable {
    associatedtype Item: Sendable

    func save(batch: [Item]) async throws -> URL
    func loadAllBatchURLs() async throws -> [URL]
    func deleteBatchFile(at url: URL) async throws
}
