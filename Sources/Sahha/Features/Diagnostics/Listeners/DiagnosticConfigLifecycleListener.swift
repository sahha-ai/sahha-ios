final class DiagnosticConfigLifecycleListener: LifecycleListener, @unchecked Sendable {
    private let uploadService: DiagnosticUploadServiceProtocol

    init(uploadService: DiagnosticUploadServiceProtocol) {
        self.uploadService = uploadService
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        await uploadService.checkConfigAndUploadIfRequested()
    }
}
