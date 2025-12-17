import Foundation

actor DataLogPipeline: DataLogPipelineProtocol, Disposable {
    private let uploader: DataLogUploaderProtocol

    private var disposed = false

    init(
        uploader: DataLogUploaderProtocol
    ) {
        self.uploader = uploader
    }

    func ingest(_ logs: [DataLog]) async {
        guard !disposed else { return }

        await uploader.enqueueLogs(logs)
    }

    func ingest(_ log: DataLog) async {
        await ingest([log])
    }

    func dispose() async {
        disposed = true
    }
}
