/// Retries pending tag uploads when the app wakes from suspension.
///
/// This listener re-triggers the upload loop on app resume and unlock events,
/// ensuring persisted batches are retried.
final class TagRetryLifecycleListener: LifecycleListener, @unchecked Sendable {
    private let uploader: TagUploaderProtocol

    init(uploader: TagUploaderProtocol) {
        self.uploader = uploader
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        Sahha.log("[TagRetry] App lifecycle event: \(event.rawValue) — checking for pending uploads")
        await uploader.retryPendingUploads()
    }
}
