import Foundation

final class BatchFileManager {
    private let logger: LoggerProtocol
    private let fileManager: FileManager
    private let directory: URL

    init(directory: URL, fileManager: FileManager = .default, logger: LoggerProtocol) throws {
        self.logger = logger
        self.directory = directory
        self.fileManager = fileManager

        logger.info("Batch directory set to: \(directory.absoluteString)")
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
    }

    func saveBatch<T: Encodable>(_ batch: [T]) -> URL? {
        let fileName = generateFileName()
        let fileURL = directory.appendingPathComponent(fileName)
        do {
            let data = try JSONEncoder().encode(batch)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            logger.error(
                "Failed to save batch to \(fileURL): \(error)", file: #file, function: #function
            )
            return nil
        }
    }

    private func generateFileName() -> String {
        let timestamp = Date().timeIntervalSince1970
        let uuid = UUID().uuidString
        return "\(timestamp)_\(uuid).json"
    }

    func loadBatches<T: Decodable>() -> [([T], URL)] {
        let files = listBatchFiles()
        return files.compactMap { self.loadBatch(form: $0) }
    }

    func deleteBatch(at fileURL: URL) throws {
        try fileManager.removeItem(at: fileURL)
    }

    func deleteAllBatches() throws {
        try fileManager.removeItem(at: directory)
    }

    private func loadBatch<T: Decodable>(form fileURL: URL) -> ([T], URL)? {
        do {
            let data = try Data(contentsOf: fileURL)
            let batch = try JSONDecoder().decode([T].self, from: data)
            return (batch, fileURL)
        } catch {
            logger.error("Failed to load batch from \(fileURL): \(error)", file: #file, function: #function)
            return nil
        }
    }

    private func listBatchFiles() -> [URL] {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            return files.filter { $0.pathExtension == "json" }
        } catch {
            logger.error("Failed to list batch files: \(error.localizedDescription)", file: #file, function: #function)
            return []
        }
    }
}
