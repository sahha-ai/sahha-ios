import Foundation

protocol DiagnosticUploadServiceProtocol: Sendable {
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

    func uploadDiagnosticReport() async throws {
        let report = await reportBuilder.buildReport()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var request = APIRequest(
            endpoint: APIEndpoints.diagnostic,
            method: .POST,
            requiresAuth: true
        )
        request.body = try encoder.encode(report)
        try await apiClient.send(request)
        Sahha.log("[Diagnostics] Diagnostic report uploaded successfully")
    }
}
