import Foundation

enum SahhaDirectories {
    /// App Support root for Sahha files, with no-backup attribute set
    static let base: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var baseURL = appSupport.appendingPathComponent("SahhaData", isDirectory: true)
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: baseURL.path) {
            try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
        // Exclude from iCloud backup
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? baseURL.setResourceValues(resourceValues)
        return baseURL
    }()

    /// Directory for data log batch files
    static let batches: URL = {
        let dir = base.appendingPathComponent("Batches", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()
}
