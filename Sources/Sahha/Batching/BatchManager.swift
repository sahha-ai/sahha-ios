import Foundation

final actor BatchManager<T: Sendable & Encodable> {
    private var buffer: [T] = []
    private let maxBatchSize: Int
    private let softFlushThreshold: Int

    init(maxBatchSize: Int = 100, softFlushThreshold: Int = 50) {
        self.maxBatchSize = maxBatchSize
        self.softFlushThreshold = softFlushThreshold
    }

    var isAtSoftLimit: Bool {
        buffer.count >= softFlushThreshold
    }

    func add(_ item: T) -> [T]? {
        buffer.append(item)
           if buffer.count >= maxBatchSize {
               let batch = buffer
               buffer.removeAll()
               return batch
           }
           return nil
    }

    func add(_ items: [T]) -> [[T]] {
        var batches: [[T]] = []
        for item in items {
            buffer.append(item)
            if buffer.count >= maxBatchSize {
                let batch = buffer
                buffer.removeAll()
                batches.append(batch)
            }
        }
        return batches
    }
    
    func reset() {
        buffer.removeAll()
    }
    
    func flush() -> [T] {
        defer { buffer.removeAll() }
        return buffer
    }

    func peek() -> [T] {
        return buffer
    }

    var count: Int {
        buffer.count
    }
}
