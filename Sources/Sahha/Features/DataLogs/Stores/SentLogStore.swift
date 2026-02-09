import Foundation

/// Tracks IDs of successfully uploaded logs to prevent duplicate submissions.
/// All sent log IDs are persisted for 3 days before being evicted.
/// This provides a robust deduplication window that handles:
/// - App crashes and restarts
/// - Background refresh cycles
/// - Network failures and retries
/// - HealthKit observer re-deliveries
actor SentLogStore {
    private let storage: UserDefaultsStorageProtocol
    private let maxAge: TimeInterval
    private let storageKey: String
    
    private var sentIds: [String: TimeInterval]?
    private var isLoaded = false
    
    private let maxEntries: Int
    
    static let defaultRetentionDays: Double = 3
    
    init(
        storage: UserDefaultsStorageProtocol,
        storageKey: String = StorageKeys.UserDefaults.sentLogIds,
        retentionDays: Double = defaultRetentionDays,
        maxEntries: Int = 50_000  // Increased capacity for 3-day window
    ) {
        self.storage = storage
        self.storageKey = storageKey
        self.maxAge = .days(retentionDays)
        self.maxEntries = maxEntries
        self.sentIds = nil  // Will be loaded lazily
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
    
    /// Mark IDs as successfully sent with current timestamp
    /// IDs will be retained for 3 days before automatic eviction
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
        Sahha.log("[SentLogStore] Marked \(ids.count) logs as sent (total tracked: \(totalTracked))")
    }
    
    func filterUnsent<T>(_ items: [T], idExtractor: @escaping @Sendable (T) -> String) -> [T] {
        items.filter { item in
            let id = idExtractor(item)
            return !isSent(id)
        }
    }
    
    func filterUnsentRequests(_ requests: [DataLogRequest]) -> [DataLogRequest] {
        filterUnsent(requests) { $0.id }
    }
    
    func count() -> Int {
        ensureLoaded()
        return sentIds?.count ?? 0
    }
    
    func getStatistics() -> SentLogStatistics {
        ensureLoaded()
        let now = Date().timeIntervalSince1970
        guard let sentIds = sentIds else {
            return SentLogStatistics(
                totalTracked: 0,
                validEntries: 0,
                expiredEntries: 0,
                oldestEntryAge: nil,
                newestEntryAge: nil,
                retentionDays: maxAge / 86400
            )
        }
        
        let validEntries = sentIds.filter { now - $0.value <= maxAge }
        let expiredEntries = sentIds.count - validEntries.count
        
        let oldestTimestamp = sentIds.values.min()
        let newestTimestamp = sentIds.values.max()
        
        return SentLogStatistics(
            totalTracked: sentIds.count,
            validEntries: validEntries.count,
            expiredEntries: expiredEntries,
            oldestEntryAge: oldestTimestamp.map { now - $0 },
            newestEntryAge: newestTimestamp.map { now - $0 },
            retentionDays: maxAge / 86400
        )
    }
    
    func clear() {
        ensureLoaded()
        sentIds?.removeAll()
        storage.removeObject(forKey: storageKey)
        Sahha.log("[SentLogStore] Cleared all tracked sent logs")
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
            Sahha.log("[SentLogStore] Evicted \(evicted) expired entries")
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

extension SentLogStore: Disposable {
    func dispose() async {
        sentIds?.removeAll()
    }
}

// MARK: - Statistics
struct SentLogStatistics: Sendable {
    let totalTracked: Int
    
    let validEntries: Int
    
    let expiredEntries: Int
    
    let oldestEntryAge: TimeInterval?
    let newestEntryAge: TimeInterval?
    let retentionDays: Double
    
    var description: String {
        let oldest = oldestEntryAge.map { formatAge($0) } ?? "N/A"
        let newest = newestEntryAge.map { formatAge($0) } ?? "N/A"
        return """
        SentLogStore Statistics:
        - Total tracked: \(totalTracked)
        - Valid entries: \(validEntries)
        - Expired (pending cleanup): \(expiredEntries)
        - Oldest entry: \(oldest)
        - Newest entry: \(newest)
        - Retention: \(Int(retentionDays)) days
        """
    }
    
    private func formatAge(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        if hours < 1 {
            return "\(Int(seconds / 60)) minutes ago"
        } else if hours < 24 {
            return String(format: "%.1f hours ago", hours)
        } else {
            return String(format: "%.1f days ago", hours / 24)
        }
    }
}

