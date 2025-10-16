import Foundation

actor DataLogPipeline: DataLogPipelineProtocol, Disposable {
    private let maxBatchBytes: Int
    private let maxBufferSize: Int
    private let flushInterval: TimeInterval
    private let fileManager: DataLogFileManagerProtocol
    private let requestMapper: DataLogRequestMapperProtocol
    private let uploader: DataLogUploaderProtocol

    private var disposed = false
    private var buffer: [DataLog] = []
    private var bufferWaiters: [CheckedContinuation<Void, Never>] = []
    private var flushTask: Task<Void, Never>? = nil

    init(
        fileManager: DataLogFileManagerProtocol,
        requestMapper: DataLogRequestMapperProtocol,
        uploader: DataLogUploaderProtocol,
        maxBatchKB: Int = 150,
        maxBufferSize: Int = 50_000,
        flushInterval: TimeInterval = .seconds(5)
    ) {
        self.fileManager = fileManager
        self.requestMapper = requestMapper
        self.uploader = uploader
        self.maxBatchBytes = maxBatchKB * 1024  // Store as bytes internally
        self.maxBufferSize = maxBufferSize
        self.flushInterval = flushInterval
    }

    func ingest(_ logs: [DataLog]) async {
        guard !disposed else { return }

        await waitForBufferSpace(for: logs.count)
        buffer.append(contentsOf: logs)
        tryResumeBufferWaiters()

        // Batching and flushing by size
        await flushBufferBySize()
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
        await flushBufferBySize()
        cancelFlushTimer()
    }

    func flushOnAppBackgroundOrExit() async {
        cancelFlushTimer()
        if !buffer.isEmpty {
            await flushBufferBySize()
        }
    }

    private func flushBatch(_ batch: [DataLogRequest]) async {
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
              buffer.count < maxBufferSize {
            bufferWaiters.removeFirst()
            continuation.resume()
        }
    }

    private func flushBufferBySize() async {
        var currentBatch: [DataLogRequest] = []
        let encoder = JSONEncoder()

        while !buffer.isEmpty {
            let log = buffer.first!
            let request = requestMapper.map(log)
            let testBatch = currentBatch + [request]
            if let data = try? encoder.encode(testBatch), data.count <= maxBatchBytes {
                currentBatch = testBatch
                buffer.removeFirst()
            } else {
                if !currentBatch.isEmpty {
                    await flushBatch(currentBatch)
                    currentBatch = []
                } else {
                    // Single mapped log is too large, flush it alone
                    await flushBatch([request])
                    buffer.removeFirst()
                }
            }
        }
        if !currentBatch.isEmpty {
            await flushBatch(currentBatch)
        }
    }
}
