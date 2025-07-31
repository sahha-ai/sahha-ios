import Foundation

protocol DataLogFileManagerProtocol: Actor {
    func persistBatch(_ logs: [DataLog]) async
    func getAllBatchFiles() async -> [URL]
    func readBatchFile(_ url: URL) async -> [DataLog]?
    func deleteBatchFile(_ url: URL) async
}
