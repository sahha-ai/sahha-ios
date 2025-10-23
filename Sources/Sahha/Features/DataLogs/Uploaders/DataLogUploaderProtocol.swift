import Foundation

protocol DataLogUploaderProtocol: Actor {
    func uploadPendingBatches()
    func ingestPrioritizedLogs(_ prioritizedLogs: [(DataLog, UploadPriority)]) async
}
