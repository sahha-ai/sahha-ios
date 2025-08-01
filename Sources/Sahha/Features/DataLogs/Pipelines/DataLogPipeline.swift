import Foundation

actor DataLogPipeline: DataLogPipelineProtocol, Disposable {
    private let batchSize: Int
    private let maxBufferSize: Int
    private let flushInterval: TimeInterval
    private let fileManager: DataLogFileManagerProtocol
    private let uploader: DataLogUploaderProtocol

    private var disposed = false
    private var buffer: [DataLog] = []
    private var bufferWaiters: [CheckedContinuation<Void, Never>] = []
    private var flushTask: Task<Void, Never>? = nil

    init(
        fileManager: DataLogFileManagerProtocol,
        uploader: DataLogUploaderProtocol,
        batchSize: Int = 500,
        maxBufferSize: Int = 50_000,
        flushInterval: TimeInterval = .seconds(5)
    ) {
        self.fileManager = fileManager
        self.uploader = uploader
        self.batchSize = batchSize
        self.maxBufferSize = maxBufferSize
        self.flushInterval = flushInterval
    }

    func ingest(_ logs: [DataLog]) async {
        guard !disposed else { return }
    
        await waitForBufferSpace(for: logs.count)
        buffer.append(contentsOf: logs)
        tryResumeBufferWaiters()

        while buffer.count >= batchSize {
            let batch = Array(buffer.prefix(batchSize))
            buffer.removeFirst(batchSize)
            await flushBatch(batch)
        }

        if !buffer.isEmpty && flushTask == nil {
            startFlushTimer()
        }
    }

    func ingest(_ log: DataLog) async {
        await ingest([log])
    }
    
    func dispose() async {
        disposed = true
        cancelFlushTimer()
        buffer.removeAll()
        bufferWaiters.forEach { $0.resume() }
        bufferWaiters.removeAll()
    }

    private func startFlushTimer() {
        flushTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
            await self.timerFlush()
        }
    }

    private func cancelFlushTimer() {
        flushTask?.cancel()
        flushTask = nil
    }

    private func timerFlush() async {
        guard !buffer.isEmpty else {
            cancelFlushTimer()
            return
        }
        let batch = buffer
        buffer.removeAll()
        await flushBatch(batch)
        cancelFlushTimer()
    }

    // TODO: This is currently unused?
    func flushOnAppBackgroundOrExit() async {
        cancelFlushTimer()
        if !buffer.isEmpty {
            let batch = buffer
            buffer.removeAll()
            await flushBatch(batch)
        }
    }

    private func flushBatch(_ batch: [DataLog]) async {
        guard !batch.isEmpty else { return }
        
        await fileManager.persistBatch(batch)
        await uploader.uploadPendingBatches()
    }

    private func waitForBufferSpace(for count: Int) async {
        while buffer.count + count > maxBufferSize {
            await withCheckedContinuation { continuation in
                bufferWaiters.append(continuation)
            }
        }
    }

    private func tryResumeBufferWaiters() {
        while let continuation = bufferWaiters.first,
            buffer.count < maxBufferSize
        {
            bufferWaiters.removeFirst()
            continuation.resume()
        }
    }
}
