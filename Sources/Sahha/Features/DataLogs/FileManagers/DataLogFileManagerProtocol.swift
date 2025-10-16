import Foundation

protocol DataLogFileManagerProtocol: Actor {
    func persistBatch(_ logs: [DataLogRequest]) async
    func getAllBatchFiles() async -> [URL]
    func readBatchFile(_ url: URL) async -> [DataLogRequest]?
    func deleteBatchFile(_ url: URL) async
}
