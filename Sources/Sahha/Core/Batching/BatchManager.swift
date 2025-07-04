import Foundation

final actor BatchManager<T: Codable> {
    private let batchSize: Int
    private let maxPendingBatches: Int
    private let fileManager: BatchFileManager

    private var buffer: [T] = []
    private var pendingBatches: [([T], URL)] = []

    init(batchSize: Int, maxPendingBatches: Int, fileManager: BatchFileManager) {
        self.batchSize = max(batchSize, 1)
        self.maxPendingBatches = max(maxPendingBatches, 1)
        self.fileManager = fileManager
        pendingBatches = fileManager.loadBatches()
    }

    var isAcceptingData: Bool {
        pendingBatches.count < maxPendingBatches
    }

    func add(_ item: T) {
        add([item])
    }

    func add(_ items: [T]) {
        buffer.append(contentsOf: items)
        formBatches()
    }

    private func formBatches() {
        while buffer.count >= batchSize && pendingBatches.count < maxPendingBatches {
            let batch = Array(buffer.prefix(batchSize))
            buffer.removeFirst(batchSize)
            if let fileURL = fileManager.saveBatch(batch) {
                pendingBatches.append((batch, fileURL))
                print("Created batch with \(batch.count) items")
            }
        }
    }

    func getNextBatch() -> ([T], URL)? {
        if pendingBatches.isEmpty {
            return nil
        }
        return pendingBatches.removeFirst()
    }

    func deleteBatch(url: URL) throws {
        try fileManager.deleteBatch(at: url)
    }
    
    func cleanup() async throws {
        buffer.removeAll()
        pendingBatches.removeAll()
        try fileManager.deleteAllBatches()
    }
}
