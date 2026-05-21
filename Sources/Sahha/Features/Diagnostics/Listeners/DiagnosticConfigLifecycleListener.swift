final class DiagnosticConfigLifecycleListener: LifecycleListener, @unchecked Sendable {
    private let uploadService: DiagnosticUploadServiceProtocol

    init(uploadService: DiagnosticUploadServiceProtocol) {
        self.uploadService = uploadService
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        do {
            try await uploadService.uploadDiagnosticReport()
        } catch {
            Sahha.log("[Diagnostics] Upload failed on \(event): \(error.localizedDescription)")
        }
    }
}
