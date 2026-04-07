import Foundation

/// Validates and cleans up persisted batches from the legacy DataLog and Tag dead
/// letter queues on first launch after the unified pipeline update.
///
/// The old and new DLQ formats are structurally identical in JSON:
///   - Same field names (id, chunk, timestamp, attemptCount, lastError)
///   - Same priority raw values (0=low, 1=normal, 2=high, 3=critical)
///   - Same directory locations
///
/// So the new `UnifiedDeadLetterQueue` naturally reads old files. This migrator
/// runs once to verify compatibility and remove any corrupt files that can't
/// be decoded in the new format.
enum DLQMigrator {
    private static let migrationKey = "dlq_migration_v1_complete"

    /// Run migration validation once. Safe to call multiple times — no-ops after first run.
    static func migrateIfNeeded(
        storage: UserDefaultsStorageProtocol
    ) async {
        guard storage.get(forKey: migrationKey) == nil else { return }

        let dataLogResult = await validateDirectory(
            StorageDirectories.dataLogs.appendingPathComponent("PersistentQueue"),
            as: DataLogRequest.self,
            label: "DataLog"
        )

        let tagResult = await validateDirectory(
            StorageDirectories.tags.appendingPathComponent("PersistentQueue"),
            as: TagRequest.self,
            label: "Tag"
        )

        if dataLogResult.total > 0 || tagResult.total > 0 {
            Sahha.log("[DLQMigrator] Validated legacy queues: \(dataLogResult.valid) DataLog batches OK, \(tagResult.valid) Tag batches OK")
            if dataLogResult.corrupt > 0 || tagResult.corrupt > 0 {
                Sahha.log("[DLQMigrator] Removed \(dataLogResult.corrupt + tagResult.corrupt) corrupt batch files")
            }
        }

        storage.set(true, forKey: migrationKey)
    }

    // MARK: - Validation

    private struct ValidationResult {
        let total: Int
        let valid: Int
        let corrupt: Int
    }

    /// Validate all JSON files in a legacy PersistentQueue directory can be decoded
    /// by the new unified format. Remove any that can't be decoded.
    private static func validateDirectory<Request: UploadableRequest>(
        _ directory: URL,
        as requestType: Request.Type,
        label: String
    ) async -> ValidationResult {
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return ValidationResult(total: 0, valid: 0, corrupt: 0)
        }

        let jsonFiles = files.filter { $0.pathExtension == "json" }
        guard !jsonFiles.isEmpty else {
            return ValidationResult(total: 0, valid: 0, corrupt: 0)
        }

        let decoder = JSONDecoder()
        var validCount = 0
        var corruptCount = 0

        for fileURL in jsonFiles {
            if let data = try? Data(contentsOf: fileURL),
               let _ = try? decoder.decode(PersistedBatch<Request>.self, from: data) {
                validCount += 1
            } else {
                // Can't decode with new format — remove corrupt file
                try? fileManager.removeItem(at: fileURL)
                corruptCount += 1
            }
        }

        return ValidationResult(total: jsonFiles.count, valid: validCount, corrupt: corruptCount)
    }
}
