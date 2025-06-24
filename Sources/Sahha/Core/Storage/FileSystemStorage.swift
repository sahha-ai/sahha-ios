import Foundation

protocol FileSystemStorageProtocol<T> {
    associatedtype T: Codable & Sendable
    func write(_ object: T, fileName: String) async throws -> URL
    func read(fileName: String) async throws -> T
    func deleteFile(fileName: String) async throws
    func listNames(includeDirectories: Bool) async throws -> [String]
    func deleteAllFiles() async throws
}

enum FileSystemError: Error, LocalizedError {
    case directoryCreationFailed(String)
    case writeFailed(String)
    case readFailed(String)
    case updateFailed(String)
    case deleteFileFailed(String)
    case deleteDirectoryFailed(String)
    case invalidName(String)
    case baseDirectoryNotFound

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let reason):
            return "Failed to create directory: \(reason)"
        case .writeFailed(let reason):
            return "Failed to write file: \(reason)"
        case .readFailed(let reason):
            return "Failed to read file: \(reason)"
        case .updateFailed(let reason):
            return "Failed to update file: \(reason)"
        case .deleteFileFailed(let reason):
            return "Failed to delete file: \(reason)"
        case .deleteDirectoryFailed(let reason):
            return "Failed to delete directory: \(reason)"
        case .invalidName(let reason):
            return "Invalid name: \(reason)"
        case .baseDirectoryNotFound:
            return "Application support directory not found"
        }
    }
}

actor FileSystemStorage<T: Codable & Sendable>: FileSystemStorageProtocol {
    private let baseDirectory: URL
    private let fileExtension = "json"

    init(baseDirectoryName: String) throws {
        guard !baseDirectoryName.isEmpty, !baseDirectoryName.contains("/") else {
            throw FileSystemError.invalidName(
                "Directory name cannot be empty or contain '/'"
            )
        }
        guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw FileSystemError.baseDirectoryNotFound
        }
        var baseDirectory = applicationSupportURL.appendingPathComponent(baseDirectoryName)

        do {
            try FileManager.default.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try baseDirectory.setResourceValues(resourceValues)
            self.baseDirectory = baseDirectory
        } catch {
            throw FileSystemError.directoryCreationFailed(
                error.localizedDescription
            )
        }
    }

    func write(_ object: T, fileName: String) async throws -> URL {
        guard !fileName.isEmpty, !fileName.contains("/") else {
            throw FileSystemError.invalidName(
                "File name cannot be empty or contain '/'"
            )
        }
        let fileURL = baseDirectory.appendingPathComponent(
            "\(fileName).\(fileExtension)"
        )
        do {
            let data = try JSONEncoder().encode(object)
            try await Task.detached {
                try data.write(to: fileURL, options: [.atomic])
            }.value
            return fileURL
        } catch let error as EncodingError {
            throw FileSystemError.writeFailed(
                "Encoding failed: \(error.localizedDescription)"
            )
        } catch {
            throw FileSystemError.writeFailed(error.localizedDescription)
        }
    }

    func read(fileName: String) async throws -> T {
        guard !fileName.isEmpty, !fileName.contains("/") else {
            throw FileSystemError.invalidName(
                "File name cannot be empty or contain '/'"
            )
        }
        let fileURL = baseDirectory.appendingPathComponent(
            "\(fileName).\(fileExtension)"
        )
        do {
            let data = try await Task.detached {
                try Data(contentsOf: fileURL)
            }.value
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw FileSystemError.readFailed(
                "Decoding failed: \(error.localizedDescription)"
            )
        } catch {
            throw FileSystemError.readFailed(error.localizedDescription)
        }
    }

    func deleteFile(fileName: String) async throws {
        guard !fileName.isEmpty, !fileName.contains("/") else {
            throw FileSystemError.invalidName(
                "File name cannot be empty or contain '/'"
            )
        }
        let fileURL = baseDirectory.appendingPathComponent(
            "\(fileName).\(fileExtension)"
        )
        try await Task.detached {
            try FileManager.default.removeItem(at: fileURL)
        }.value
    }

    func listNames(includeDirectories: Bool) async throws -> [String] {
        try await Task.detached {
            let contents = try FileManager.default.contentsOfDirectory(
                at: self.baseDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            return try contents.compactMap { url in
                let resourceValues = try url.resourceValues(forKeys: [
                    .isDirectoryKey
                ])
                if resourceValues.isDirectory == true {
                    return includeDirectories ? url.lastPathComponent : nil
                } else {
                    guard url.pathExtension == self.fileExtension else {
                        return nil
                    }
                    return url.deletingPathExtension().lastPathComponent
                }
            }
        }.value
    }

    func deleteAllFiles() async throws {
        let fileNames = try await listNames(includeDirectories: false)
        for fileName in fileNames {
            try await deleteFile(fileName: fileName)
        }
    }
}
