import Foundation

protocol DataLogUploaderProtocol: Actor {
    func uploadPendingBatches()
}
