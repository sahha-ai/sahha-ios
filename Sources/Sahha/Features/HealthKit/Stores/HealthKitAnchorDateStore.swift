import HealthKit

actor HealthKitAnchorDateStore: HealthKitAnchorDateStoreProtocol, Disposable {
    private let prefix = StorageKeys.UserDefaults.hkAnchorDatePrefix
    /// Pre-rename SDKs prefixed the already-prefixed key again — note `date_`,
    /// not the anchor store's `sahha_`. Reads still honour those keys and
    /// dispose must wipe them too.
    private let legacyKeyPrefix = "date_"
    private let storage: UserDefaultsStorageProtocol
    /// Latched by `dispose()` (container teardown, e.g. deauthentication). A straggling
    /// activity-summary upload that resolves after teardown must not save its date
    /// back — the next session would silently skip the days behind it.
    private var disposed = false

    init(storage: UserDefaultsStorageProtocol) {
        self.storage = storage
    }

    func saveAnchorDate(_ date: Date, forKey key: String) {
        guard !disposed else { return }
        let key = prefix + key
        storage.set(date, forKey: key)
    }

    func loadAnchorDate(forKey key: String) -> Date? {
        // No old-name alias here, unlike the anchor store: this namespace only
        // ever holds the activity-summary key, which was not renamed.
        let key = prefix + key
        if let date = storage.date(forKey: key) {
            return date
        }
        // Try legacy storage key
        return storage.date(forKey: legacyKeyPrefix + key)
    }

    func dispose() async {
        disposed = true
        // Wipes the legacy-prefixed family too: a legacy-key date that
        // survives deauth would be resurrected by the fallback read.
        let keys = storage.allKeys {
            $0.hasPrefix(self.prefix) || $0.hasPrefix(self.legacyKeyPrefix + self.prefix)
        }
        keys.forEach(storage.removeObject)
    }
}
