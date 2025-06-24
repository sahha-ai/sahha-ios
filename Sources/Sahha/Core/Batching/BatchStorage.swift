import Foundation

protocol BatchStorageProtocol<T>: Actor {
    associatedtype T: Codable & Sendable
    func saveBatch(_ identifiedBatch: IdentifiedBatch<T>) async throws -> URL
    func loadBatch(id: String) async throws -> IdentifiedBatch<T>
    func loadBatches() async throws -> [IdentifiedBatch<T>]
    func deleteBatch(id: String) async throws
    func deleteAllBatches() async throws
}

actor BatchStorage<T: Codable & Sendable>: BatchStorageProtocol {
    private let storage: FileSystemStorage<[T]>

    init(baseDirectoryName: String) throws {
        self.storage = try FileSystemStorage(baseDirectoryName: baseDirectoryName)
    }

    func saveBatch(_ identifiedBatch: IdentifiedBatch<T>) async throws -> URL {
        let timestamp = Date().unixTimestamp
        let fileName = "\(timestamp)_\(identifiedBatch.id)"
        return try await storage.write(
            identifiedBatch.batch,
            fileName: fileName
        )
    }

    func loadBatch(id: String) async throws -> IdentifiedBatch<T> {
        let fileNames = try await storage.listNames(includeDirectories: false)
        guard let fileName = fileNames.first(where: { $0.hasSuffix("_\(id)") }) else {
            throw FileSystemError.readFailed("No batch file found for ID \(id)")
        }
        let batch = try await storage.read(fileName: fileName)
        return IdentifiedBatch(id: id, batch: batch)
    }

    func loadBatches() async throws -> [IdentifiedBatch<T>] {
        let fileNames = try await storage.listNames(includeDirectories: false)
        var result: [IdentifiedBatch<T>] = []
        for fileName in fileNames {
            if let id = extractId(from: fileName) {
                let batch = try await storage.read(fileName: fileName)
                let identifiedBatch = IdentifiedBatch(id: id, batch: batch)
                result.append(identifiedBatch)
            }
        }
        return result
    }

    func deleteBatch(id: String) async throws {
        let fileNames = try await storage.listNames(includeDirectories: false)
        guard let fileName = fileNames.first(where: { $0.hasSuffix("_\(id)") }) else {
            return  // Ignore if file doesn't exist
        }
        try await storage.deleteFile(fileName: fileName)
    }

    func deleteAllBatches() async throws {
        try await storage.deleteAllFiles()
    }

    private func extractId(from fileName: String) -> String? {
        let components = fileName.split(separator: "_")
        if let lastComponent = components.last {
            return String(lastComponent)
        }
        return nil
    }
}
