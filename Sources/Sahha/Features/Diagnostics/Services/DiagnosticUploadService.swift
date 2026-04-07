import Foundation

protocol DiagnosticUploadServiceProtocol: Sendable {
    func checkConfigAndUploadIfRequested() async
    func uploadDiagnosticReport() async throws
}

final class DiagnosticUploadService: DiagnosticUploadServiceProtocol, @unchecked Sendable {
    private let apiClient: APIClientProtocol
    private let reportBuilder: DiagnosticReportBuilderProtocol
    private let logger: ErrorLoggerProtocol

    init(
        apiClient: APIClientProtocol,
        reportBuilder: DiagnosticReportBuilderProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.apiClient = apiClient
        self.reportBuilder = reportBuilder
        self.logger = logger
    }

    func checkConfigAndUploadIfRequested() async {
        do {
            let request = APIRequest(
                endpoint: APIEndpoints.config,
                method: .GET,
                requiresAuth: true
            )
            let config: ProfileConfig = try await apiClient.send(request)
            guard config.diagnosticRequested == true else { return }

            Sahha.log("[Diagnostics] Server requested diagnostic report — collecting and uploading")
            try await uploadDiagnosticReport()
        } catch {
            // Silently ignore config check failures — best effort only
            Sahha.log("[Diagnostics] Config check failed: \(error.localizedDescription)")
        }
    }

    func uploadDiagnosticReport() async throws {
        let report = await reportBuilder.buildReport()
        let request = APIRequest(
            endpoint: APIEndpoints.diagnostic,
            method: .POST,
            body: report,
            requiresAuth: true
        )
        try await apiClient.send(request)
        Sahha.log("[Diagnostics] Diagnostic report uploaded successfully")
    }
}
