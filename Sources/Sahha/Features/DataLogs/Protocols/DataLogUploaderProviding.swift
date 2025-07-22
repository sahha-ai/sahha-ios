import Foundation

protocol DataLogUploading: Actor, Disposable {
    func enqueue(_ batchURL: URL)
    func uploadPendingBatches()
}
