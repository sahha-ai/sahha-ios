import Foundation

protocol BatchUploader: Actor, Disposable {
    func upload(url: URL) async
}
