import Foundation

/// Tracks IDs of successfully uploaded items to prevent duplicate submissions.
/// All sent IDs are persisted for 3 days before being evicted.
/// This provides a robust deduplication window that handles:
/// - App crashes and restarts
/// - Background refresh cycles
/// - Network failures and retries
/// - HealthKit observer re-deliveries
actor SentItemStore: Disposable {
    private let storage: UserDefaultsStorageProtocol
    private let maxAge: TimeInterval
    private let storageKey: String
    private let logLabel: String

    private var sentIds: [String: TimeInterval]?
    private var isLoaded = false
    /// Latched by `dispose()` (container teardown, e.g. deauthentication). An upload
    /// flight that resolves after teardown must not write sent-IDs back into the
    /// wiped dedup store — the next session's re-queried history would be filtered
    /// as "already sent" and silently never re-upload.
    private var disposed = false

    private let maxEntries: Int

    static let defaultRetentionDays: Double = 3

    init(
        storage: UserDefaultsStorageProtocol,
        storageKey: String,
        logLabel: String = "SentItemStore",
        retentionDays: Double = defaultRetentionDays,
        maxEntries: Int = 50_000
    ) {
        self.storage = storage
        self.storageKey = storageKey
        self.logLabel = logLabel
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

    func filterSentIds(_ ids: [String]) -> Set<String> {
        ensureLoaded()
        let now = Date().timeIntervalSince1970
        var sent = Set<String>()
        guard let sentIds = sentIds else { return sent }

        for id in ids {
            if let timestamp = sentIds[id], now - timestamp <= maxAge {
                sent.insert(id)
            }
        }

        return sent
    }

    func markSent(_ ids: [String]) {
        guard !disposed, !ids.isEmpty else { return }
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
        Sahha.log("[\(logLabel)] Marked \(ids.count) items as sent (total tracked: \(totalTracked))")
    }

    func filterUnsent<T>(_ items: [T], idExtractor: @escaping @Sendable (T) -> String) -> [T] {
        items.filter { item in
            let id = idExtractor(item)
            return !isSent(id)
        }
    }

    func filterUnsentRequests<R: UploadableRequest>(_ requests: [R]) -> [R] {
        filterUnsent(requests) { $0.id }
    }

    func count() -> Int {
        ensureLoaded()
        return sentIds?.count ?? 0
    }

    func clear() {
        ensureLoaded()
        sentIds?.removeAll()
        storage.removeObject(forKey: storageKey)
        Sahha.log("[\(logLabel)] Cleared all tracked sent items")
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
            Sahha.log("[\(logLabel)] Evicted \(evicted) expired entries")
        }
    }

    func dispose() async {
        disposed = true
        sentIds?.removeAll()
        storage.removeObject(forKey: storageKey)
    }

    // MARK: - Private Helpers

    private func saveToStorage() {
        // The disposed check also covers eviction/cleanup writes: every path that
        // persists the dedup set funnels through here.
        guard !disposed, let sentIds = sentIds, let data = try? JSONEncoder().encode(sentIds) else { return }
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
