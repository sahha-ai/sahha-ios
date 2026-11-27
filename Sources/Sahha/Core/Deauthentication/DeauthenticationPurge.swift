import Foundation

/// The static, container-free half of deauthentication (PRD #76 D13).
///
/// Deauthentication is a hybrid teardown in load-bearing order: the DI
/// container reset runs first and disposes every *resolved* service — only
/// dispose can stop live observer queries, disable HealthKit background
/// deliveries (registrations the OS keeps across process launches, beyond any
/// key wipe), and set the write-back latches — then this routine wipes the
/// enumerated inventory of SDK-owned persistent state, covering everything a
/// partially-resolved (or never-configured) session's reset cannot reach. It
/// needs no DI container, which is what makes deauthentication total: it
/// succeeds before `configure` has ever run.
///
/// Every entry is a `StorageKeys` constant, and the storage-keys completeness
/// test asserts each constant appears in exactly one of the purge/keep lists
/// below — a future key added without an explicit purge decision fails the
/// suite.
enum DeauthenticationPurge {
    /// Whole-value UserDefaults keys the purge removes. `profileId` is the
    /// data-log identity: it survives session expiry by design, and this purge
    /// is the one place it dies.
    static let purgedUserDefaultsKeys: [StorageKeys.UserDefaults] = [
        .deviceInfo,
        .profileId,
        .sensors,
        .sentLogIds,
        .sentTagIds,
        .diagnosticReport,
        .dlqMigration,
    ]

    /// UserDefaults keys that deliberately survive deauthentication.
    /// `deviceId` is vendor-derived device identity, not profile state —
    /// purging it would desync mappers that captured it by value.
    static let keptUserDefaultsKeys: [StorageKeys.UserDefaults] = [
        .deviceId,
    ]

    /// Every key family is purged wholesale, canonical and legacy alias forms
    /// alike — a surviving alias key would be resurrected by the stores'
    /// fallback reads.
    static let purgedUserDefaultsPrefixes: [StorageKeys.UserDefaultsPrefix] =
        StorageKeys.UserDefaultsPrefix.allCases

    /// Keychain keys the purge removes: the session token, and the demographic
    /// cache — profile PII that must not survive into the next account.
    static let purgedKeychainKeys: [StorageKeys.Keychain] = [
        .token,
        .demographic,
    ]

    /// Keychain keys that survive deauthentication: none.
    static let keptKeychainKeys: [StorageKeys.Keychain] = []

    /// Both upload pipelines' storage directories (dead-letter queues). The
    /// fresh queues recreate them on the next configure.
    static var purgedDirectories: [URL] {
        [StorageDirectories.dataLogs, StorageDirectories.tags]
    }

    /// Wipes the enumerated inventory. Never throws and never partially
    /// aborts: each item is removed independently, so one failing store cannot
    /// shield the rest, and re-running converges on the same empty state.
    static func run(
        userDefaults: UserDefaultsStorageProtocol = UserDefaultsStorage(),
        keychain: KeychainStorageProtocol = KeychainStorage(),
        directories: [URL] = DeauthenticationPurge.purgedDirectories
    ) {
        for key in purgedUserDefaultsKeys {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        let prefixes = purgedUserDefaultsPrefixes.map(\.rawValue)
        let familyKeys = userDefaults.allKeys { key in
            prefixes.contains { key.hasPrefix($0) }
        }
        for key in familyKeys {
            userDefaults.removeObject(forKey: key)
        }
        for key in purgedKeychainKeys {
            try? keychain.removeObject(forKey: key.rawValue)
        }
        for directory in directories {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
