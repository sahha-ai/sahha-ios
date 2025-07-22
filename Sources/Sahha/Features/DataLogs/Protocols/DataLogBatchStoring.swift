import Foundation

protocol DataLogBatchStoring: Actor, Disposable {
    func save(batch: [DataLog]) async throws -> URL
    func load(url: URL) async throws -> [DataLog]
    func delete(url: URL) async throws
    func listAllBatches() async throws -> [URL]
}
