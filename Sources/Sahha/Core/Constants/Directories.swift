import Foundation

enum Directories {
    static let baseDirectory = getBaseDirectory()
    
    static let dataLogDirectory =  subdirectory(parent: baseDirectory, name: "data-logs")
    static let dataLogBatchDirectory =  subdirectory(parent: dataLogDirectory, name: "batches")
    
    static func subdirectory(parent: URL, name: String) -> URL {
        let dirURL = parent.appendingPathComponent(name, isDirectory: true)
        ensureDirectory(at: dirURL)
        excludeFromBackup(url: dirURL)
        return dirURL
    }
    
    private static func getBaseDirectory() -> URL {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var baseURL = appSupportURL.appendingPathComponent("sahha")
        ensureDirectory(at: baseURL)
        excludeFromBackup(url: baseURL)
        return baseURL
    }
    
    @discardableResult
    private static func ensureDirectory(at url: URL) -> Bool {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create directory at \(url): \(error)")
                return false
            }
        }
        return true
    }

    private static func excludeFromBackup(url: URL) {
        var url = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? url.setResourceValues(resourceValues)
    }
}
