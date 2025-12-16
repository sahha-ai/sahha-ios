import Foundation

protocol DataLogUploaderProtocol: Actor {
    func enqueue(_ chunk: DataLogChunk) async
    func enqueueLogs(_ logs: [DataLog]) async
    func dispose() async
}
