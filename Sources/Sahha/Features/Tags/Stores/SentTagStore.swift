import Foundation

/// Tracks IDs of successfully uploaded tags to prevent duplicate submissions.
/// All sent tag IDs are persisted for 3 days before being evicted.
actor SentTagStore {
    private let storage: UserDefaultsStorageProtocol
    private let maxAge: TimeInterval
    private let storageKey: String

    private var sentIds: [String: TimeInterval]?
    private var isLoaded = false

    private let maxEntries: Int

    static let defaultRetentionDays: Double = 3

    init(
        storage: UserDefaultsStorageProtocol,
        storageKey: String = StorageKeys.UserDefaults.sentTagIds,
        retentionDays: Double = defaultRetentionDays,
        maxEntries: Int = 50_000
    ) {
        self.storage = storage
        self.storageKey = storageKey
        self.maxAge = .days(retentionDays)
        self.maxEntries = maxEntries
        self.sentIds = nil
    }

    private func ensureLoaded() {
        guard !isLoaded else { return }
        isLoaded = true

        if let data = storage.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            let now = Date().timeIntervalSince1970
            sentIds = decoded.filter { now - $0.value <= maxAge }
        } else {
            sentIds = [:]
        }
    }

    // MARK: - Public API

    func isSent(_ id: String) -> Bool {
        ensureLoaded()
        guard var currentIds = sentIds,
              let timestamp = currentIds[id] else { return false }

        let now = Date().timeIntervalSince1970
        if now - timestamp > maxAge {
            currentIds.removeValue(forKey: id)
            sentIds = currentIds
            return false
        }

        return true
    }

    func markSent(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        ensureLoaded()

        let now = Date().timeIntervalSince1970

        for id in ids {
            sentIds?[id] = now
        }

        if let count = sentIds?.count, count > maxEntries {
            cleanup()
        }

        saveToStorage()

        let totalTracked = sentIds?.count ?? 0
        Sahha.log("[SentTagStore] Marked \(ids.count) tags as sent (total tracked: \(totalTracked))")
    }

    func filterUnsentRequests(_ requests: [TagRequest]) -> [TagRequest] {
        requests.filter { !isSent($0.id) }
    }

    func clear() {
        ensureLoaded()
        sentIds?.removeAll()
        storage.removeObject(forKey: storageKey)
        Sahha.log("[SentTagStore] Cleared all tracked sent tags")
    }

    func evictExpired() {
        ensureLoaded()
        guard var currentIds = sentIds else { return }
        let beforeCount = currentIds.count
        let now = Date().timeIntervalSince1970
        currentIds = currentIds.filter { now - $0.value <= maxAge }
        sentIds = currentIds
        let evicted = beforeCount - currentIds.count

        if evicted > 0 {
            saveToStorage()
            Sahha.log("[SentTagStore] Evicted \(evicted) expired entries")
        }
    }

    // MARK: - Private Helpers

    private func saveToStorage() {
        guard let sentIds = sentIds, let data = try? JSONEncoder().encode(sentIds) else { return }
        storage.set(data, forKey: storageKey)
    }

    private func cleanup() {
        guard var currentIds = sentIds else { return }
        let now = Date().timeIntervalSince1970

        currentIds = currentIds.filter { now - $0.value <= maxAge }

        if currentIds.count > maxEntries {
            let sorted = currentIds.sorted { $0.value < $1.value }
            let toKeep = Array(sorted.suffix(maxEntries / 2))
            currentIds = Dictionary(uniqueKeysWithValues: toKeep)
        }

        sentIds = currentIds
        saveToStorage()
    }
}

// MARK: - Disposable

extension SentTagStore: Disposable {
    func dispose() async {
        sentIds?.removeAll()
    }
}
