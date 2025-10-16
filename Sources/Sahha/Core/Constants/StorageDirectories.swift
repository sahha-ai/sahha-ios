import Foundation

enum StorageDirectories {
    /// The base directory for all SDK persistent data (never backed up)
    static var base: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("sahha", isDirectory: true)
        ensureExcludedFromBackup(dir)
        return dir
    }

    static var dataLogs: URL {
        base.appendingPathComponent("data-logs", isDirectory: true)
    }

    /// Helper: Ensures a directory is excluded from backup (no-op if already set)
    @discardableResult
    private static func ensureExcludedFromBackup(_ dir: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir)
        guard exists, isDir.boolValue else { return false }
        do {
            try (dir as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
            return true
        } catch {
            #if DEBUG
                print("[\(SDK.name)] - ERROR: Failed to exclude \(dir.path) from backup: \(error)")
            #endif
            return false
        }
    }
}
