import Foundation

final actor BatchUploader<T: Sendable & Encodable> {
    private let maxConcurrentUploads: Int

    init(maxConcurrentUploads: Int = 5) {
        self.maxConcurrentUploads = maxConcurrentUploads
    }

    func enqueue(_ batch: [T]) async {
        // TODO: implement background upload with retry + backoff
    }
}
