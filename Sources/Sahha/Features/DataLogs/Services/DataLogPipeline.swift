import Foundation

final actor DataLogPipeline: DataLogPipelineProviding {
    private let batchSize: Int
    private let batchStorage: DataLogBatchStoring
    private let uploader: DataLogUploading
    private let flushInterval: TimeInterval
    private let maxBufferSize: Int

    private var buffer: [DataLog] = []
    private var flushTimer: Timer?
    private var bufferWaiters: [CheckedContinuation<Void, Never>] = []
    private var disposed = false

    private var pendingTickets: [IngestionTicket] = []

    init(
        batchSize: Int = 100,
        batchStorage: DataLogBatchStoring,
        uploader: DataLogUploading,
        flushInterval: TimeInterval = .seconds(15),
        maxBufferSize: Int = 20_000
    ) {
        self.batchSize = batchSize
        self.batchStorage = batchStorage
        self.uploader = uploader
        self.flushInterval = flushInterval
        self.maxBufferSize = maxBufferSize
    }

    /// Ingest logs, suspending if buffer is full. Only resumes once *these logs* have been persisted.
    func ingest(_ logs: [DataLog]) async throws {
        guard !disposed else { throw CancellationError() }

        // Enforce max buffer size, suspend if needed
        while buffer.count + logs.count > maxBufferSize {
            await withCheckedContinuation { cont in
                bufferWaiters.append(cont)
            }
            if disposed { throw CancellationError() }
        }

        // Record ticket for this ingest
        let startIdx = buffer.count
        buffer.append(contentsOf: logs)
        let endIdx = buffer.count

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let ticket = IngestionTicket(start: startIdx, end: endIdx, continuation: cont)
            pendingTickets.append(ticket)
            // If enough logs to trigger flush, flush immediately
            if buffer.count >= batchSize {
                Task {
                    await self.flush()
                }
            } else {
                scheduleFlushTimer()
            }
        }
    }

    /// Schedule a flush for when buffer is not full but we don't want to wait forever.
    private func scheduleFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: false) { [weak self] _ in
            Task { await self?.flush() }
        }
    }

    /// Flush buffer in batches of batchSize. Resume only tickets for logs included in each batch.
    private func flush() async {
        guard !disposed else { return }

        flushTimer?.invalidate()
        flushTimer = nil

        guard buffer.notEmpty else { return }

        var logsProcessed = 0
        while buffer.count > 0 {
            guard !disposed else { return }

            // Pull the next batch
            let batchCount = min(batchSize, buffer.count)
            let logsToFlush = Array(buffer.prefix(batchCount))
            buffer.removeFirst(batchCount)

            // Find tickets whose logs are fully contained in this batch
            var fulfilledTickets: [Int] = []
            for (i, ticket) in pendingTickets.enumerated() {
                // If this ticket's logs all fall within logsProcessed..<logsProcessed+batchCount
                if ticket.end <= logsProcessed + batchCount {
                    fulfilledTickets.append(i)
                }
            }

            let ticketsForThisBatch = fulfilledTickets.map { pendingTickets[$0] }

            do {
                let url = try await batchStorage.save(batch: logsToFlush)
                await uploader.enqueue(url)
                // Resume all fulfilled tickets for this batch
                for ticket in ticketsForThisBatch {
                    guard !ticket.completed else { continue }
                    ticket.completed = true
                    ticket.continuation.resume()
                }
            } catch is CancellationError {
                break
            } catch {
                for ticket in ticketsForThisBatch {
                    guard !ticket.completed else { continue }
                    ticket.completed = true
                    ticket.continuation.resume(throwing: error)
                }
            }

            // Remove completed tickets from pending
            pendingTickets.removeAll { ticket in
                ticketsForThisBatch.contains(where: { $0 === ticket })
            }

            logsProcessed += batchCount
        }

        // Wake any buffer waiters now that space is available
        wakeBufferWaiters()
    }

    /// Wake as many waiting ingests as we have buffer space for.
    private func wakeBufferWaiters() {
        while bufferWaiters.notEmpty && buffer.count < maxBufferSize {
            bufferWaiters.removeFirst().resume()
        }
    }

    func dispose() async {
        disposed = true

        // Invalidate timer
        flushTimer?.invalidate()
        flushTimer = nil

        // Cancel all pending buffer waiters
        for waiter in bufferWaiters {
            waiter.resume()  // Safe, never throws. If they expect error, adjust.
        }
        bufferWaiters.removeAll()

        // Cancel all pending ingestion tickets
        for ticket in pendingTickets {
            if !ticket.completed {
                ticket.completed = true
                ticket.continuation.resume(throwing: CancellationError())
            }
        }
        pendingTickets.removeAll()

        // Clear buffer
        buffer.removeAll()
    }
}

private final class IngestionTicket {
    let start: Int
    let end: Int
    let continuation: CheckedContinuation<Void, Error>
    var completed: Bool = false

    init(start: Int, end: Int, continuation: CheckedContinuation<Void, Error>) {
        self.start = start
        self.end = end
        self.continuation = continuation
    }
}
