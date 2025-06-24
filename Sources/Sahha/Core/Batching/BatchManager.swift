import Foundation

protocol BatchManagerProtocol<T>: Actor, DisposableAsync {
    associatedtype T: Codable & Sendable
    func add(_ item: T) async throws
    func add(_ items: [T]) async throws
    func getNextBatch() async -> IdentifiedBatch<T>?
    func loadPersistedBatches() async
    func removeBatch(id: String) async throws
    var hasBatches: Bool { get }
    var isAcceptingData: Bool { get }
}

actor BatchManager<T: Codable & Sendable>: BatchManagerProtocol {
    private var currentBatch: [T] = []
    private var batches: [String: IdentifiedBatch<T>] = [:]
    private var batchQueue: [String] = []
    private let batchSize: Int
    private let maxPendingBatches: Int
    private let storage: any BatchStorageProtocol<T>

    init(
        batchSize: Int,
        maxPendingBatches: Int,
        storage: any BatchStorageProtocol<T>
    ) async {
        self.batchSize = max(1, batchSize)
        self.maxPendingBatches = max(1, maxPendingBatches)
        self.storage = storage
        await loadPersistedBatches()
    }

    func loadPersistedBatches() async {
        do {
            let persistedBatches = try await storage.loadBatches()
            for identifiedBatch in persistedBatches {
                batches[identifiedBatch.id] = identifiedBatch
            }
        } catch {
            print("Failed to load persisted batches: \(error)")
        }
    }

    func add(_ item: T) async throws {
        try await add([item])
    }

    func add(_ items: [T]) async throws {
        currentBatch.append(contentsOf: items)
        while currentBatch.count >= batchSize {
            let batchToProcess = Array(currentBatch.prefix(batchSize))
            currentBatch.removeFirst(batchSize)
            let id = UUID().uuidString
            let identifiedBatch = IdentifiedBatch(id: id, batch: batchToProcess)
            _ = try await storage.saveBatch(identifiedBatch)
            batches[id] = identifiedBatch
            batchQueue.append(id)
        }
    }

    func getNextBatch() async -> IdentifiedBatch<T>? {
        guard let id = batchQueue.first else { return nil }
        batchQueue.removeFirst()
        return batches[id]
    }

    var hasBatches: Bool {
        !batchQueue.isEmpty
    }

    var isAcceptingData: Bool {
        batches.count <= maxPendingBatches
    }

    func removeBatch(id: String) async throws {
        if batches[id] != nil {
            try await storage.deleteBatch(id: id)
            batches.removeValue(forKey: id)
        }
    }

    func dispose() async {
        currentBatch.removeAll()
        batches.removeAll()
        batchQueue.removeAll()
        do {
            try await storage.deleteAllBatches()
        } catch {
            print("Failed to delete all batches: \(error.localizedDescription)")
        }
    }
}
