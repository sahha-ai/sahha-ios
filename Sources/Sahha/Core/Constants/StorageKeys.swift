/// Every persistent key the SDK owns, grouped by backing store.
///
/// The groups are `CaseIterable` so the deauthentication purge can be proven
/// complete (PRD #76 D13): the storage-keys completeness test asserts every
/// case appears in exactly one of `DeauthenticationPurge`'s purge/keep lists,
/// so a key added here without an explicit purge decision fails the suite.
enum StorageKeys {
    /// Whole-value UserDefaults keys.
    enum UserDefaults: String, CaseIterable {
        case deviceId
        case deviceInfo
        case sensors
        case sentLogIds
        case sentTagIds
        case diagnosticReport = "com.sahha.diagnostic_report"
        case dlqMigration = "dlq_migration_v1_complete"
    }

    /// UserDefaults key families: one stored entry per member key under the
    /// prefix. The legacy variants are the doubled prefixes pre-rename SDKs
    /// wrote — reads still alias them (see the anchor stores), so dispose and
    /// the purge must wipe both forms.
    enum UserDefaultsPrefix: String, CaseIterable {
        case hkAnchor = "hkAnchor."
        case hkAnchorDate = "hkAnchorDate."
        case legacyHkAnchor = "sahha_hkAnchor."
        case legacyHkAnchorDate = "date_hkAnchorDate."
    }

    /// Keychain data keys.
    enum Keychain: String, CaseIterable {
        case token
        case demographic

        /// The keychain service namespace — not a data key.
        static let service = "ai.sahha.ios"
    }
}
