import Foundation

actor TagPipeline: TagPipelineProtocol, Disposable {
    private let uploader: TagUploaderProtocol

    private var disposed = false

    init(
        uploader: TagUploaderProtocol
    ) {
        self.uploader = uploader
    }

    func ingest(_ tags: [Tag]) async {
        guard !disposed else { return }

        await uploader.enqueueTags(tags)
    }

    func ingest(_ tag: Tag) async {
        await ingest([tag])
    }

    func dispose() async {
        disposed = true
    }
}
