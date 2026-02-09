/// Retries pending data log uploads when the app wakes from suspension.
///
/// When HealthKit background delivery wakes the app, data may be queried
/// and ingested but the upload may not complete before iOS suspends the app.
/// This listener re-triggers the upload loop on app resume and unlock events,
/// ensuring persisted batches are retried.
final class DataLogRetryLifecycleListener: LifecycleListener, @unchecked Sendable {
    private let uploader: DataLogUploaderProtocol

    init(uploader: DataLogUploaderProtocol) {
        self.uploader = uploader
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        Sahha.log("[DataLogRetry] App lifecycle event: \(event.rawValue) — checking for pending uploads")
        await uploader.retryPendingUploads()
    }
}
