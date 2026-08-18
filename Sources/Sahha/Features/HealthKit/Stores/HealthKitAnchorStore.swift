import HealthKit

actor HealthKitAnchorStore: HealthKitAnchorStoreProtocol, Disposable {
    private let prefix = StorageKeys.UserDefaults.hkAnchorPrefix
    /// Pre-rename SDKs prefixed the already-prefixed key again; reads still
    /// honour those keys and dispose must wipe them too.
    private let legacyKeyPrefix = "sahha_"
    private let storage: UserDefaultsStorageProtocol
    /// Latched by `dispose()` (container teardown, e.g. deauthentication). A straggling
    /// anchored query that resolves after teardown must not save its anchor back —
    /// the next session would silently skip all history behind it.
    private var disposed = false

    init(storage: UserDefaultsStorageProtocol) {
        self.storage = storage
    }

    func saveAnchor(_ anchor: HKQueryAnchor, forKey key: String) throws {
        guard !disposed else {
            // Throwing (rather than silently dropping) stops the caller's pagination
            // loop: an anchor that cannot advance must not keep fetching pages.
            throw SahhaError(message: "Anchor store has been disposed.")
        }
        let key = prefix + key
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: anchor,
            requiringSecureCoding: true
        )
        storage.set(data, forKey: key)
    }

    func loadAnchor(forKey key: String) throws -> HKQueryAnchor? {
        // Read-time alias for renamed sensors: canonical key first (both
        // prefix forms), then the old-name key the pre-rename SDK wrote. The
        // alias is permanent, not transitional — saves are canonical but not
        // prompt (coordinators skip saving when a query returns no samples),
        // and the old key is deliberately never deleted: deletion is worse on
        // downgrade, where the old binary would re-backfill.
        var anchorData = data(forUnprefixedKey: key)
        if anchorData == nil, let legacyName = SahhaSensor.currentToLegacyRawValue[key] {
            anchorData = data(forUnprefixedKey: legacyName)
        }
        guard let anchorData else { return nil }
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: anchorData)
        unarchiver.requiresSecureCoding = true
        return unarchiver.decodeObject(of: HKQueryAnchor.self, forKey: NSKeyedArchiveRootObjectKey)
    }

    func dispose() async {
        disposed = true
        // Wipes the legacy-prefixed family too: a legacy-key anchor that
        // survives deauth would be resurrected by the fallback read.
        let keys = storage.allKeys {
            $0.hasPrefix(self.prefix) || $0.hasPrefix(self.legacyKeyPrefix + self.prefix)
        }
        keys.forEach(storage.removeObject)
    }

    private func data(forUnprefixedKey key: String) -> Data? {
        let key = prefix + key
        return storage.data(forKey: key) ?? storage.data(forKey: legacyKeyPrefix + key)
    }
}
