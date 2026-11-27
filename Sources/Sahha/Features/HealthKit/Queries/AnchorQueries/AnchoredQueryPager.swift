import HealthKit

/// Fetches anchored-query pages for the data-log and tag coordinators, with three
/// defences against a page that does not come back in time:
///
/// - Pages queue for a slot in a semaphore that both coordinators share, so a launch
///   that fires every enabled sensor's observer at once does not put every query on
///   HealthKit at once. A page's timeout starts only once it holds a slot.
/// - A sensor whose page times out requests smaller pages from then on, one step per
///   timeout, and returns to full size once a run catches up to an empty page.
/// - A timeout reports what the page was doing, in `AnchoredQueryTimeoutContext`.
///
/// Shrunk page sizes live in memory: a relaunched process starts at full size again.
actor AnchoredQueryPager {
    /// Anchored queries allowed at once across both coordinators. Enough to keep
    /// pagination moving, few enough to keep HealthKit responsive; worth revisiting
    /// once timeout reports carry slot occupancy.
    static let defaultConcurrencyLimit = 4
    /// The smaller page sizes tried, in order, after timeouts at the full size.
    static let fallbackPageSizes = [100, 20]

    private let logLabel: String
    private let service: HealthKitAnchorQueryServiceProtocol
    private let slots: AsyncSemaphore
    private let timeout: TimeInterval
    private let appStateProvider: ApplicationStateProviding?
    /// Full size first, then the fallbacks below it.
    private let pageSizes: [Int]
    /// Index into `pageSizes` per sensor. Absent means full size.
    private var pageSizeLevels: [SahhaSensor: Int] = [:]

    init(
        logLabel: String,
        service: HealthKitAnchorQueryServiceProtocol,
        slots: AsyncSemaphore,
        fullPageSize: Int,
        timeout: TimeInterval,
        appStateProvider: ApplicationStateProviding?
    ) {
        let fullPageSize = max(1, fullPageSize)
        self.logLabel = logLabel
        self.service = service
        self.slots = slots
        self.timeout = timeout
        self.appStateProvider = appStateProvider
        self.pageSizes = [fullPageSize] + Self.fallbackPageSizes.filter { $0 < fullPageSize }
    }

    func pageSize(for sensor: SahhaSensor) -> Int {
        pageSizes[pageSizeLevels[sensor] ?? 0]
    }

    /// The sensor's run reached an empty page, so the backlog that shrank its pages
    /// is drained and its next run goes back to full-size pages.
    func sensorCaughtUp(_ sensor: SahhaSensor) {
        pageSizeLevels[sensor] = nil
    }

    /// Fetches one page at the sensor's current page size.
    /// - Throws: `AnchoredQueryTimeoutError` when the page outlives the timeout, after
    ///   shrinking the sensor's page size; `CancellationError` when the caller is
    ///   cancelled, queued or mid-query; otherwise the query's own error.
    func fetchPage(
        for sensor: SahhaSensor,
        sampleType: HKSampleType,
        startDate: Date?,
        endDate: Date?,
        anchor: HKQueryAnchor?,
        pagesCompleted: Int
    ) async throws -> ([HKSample], HKQueryAnchor?) {
        let limit = pageSize(for: sensor)
        let queuedAt = Date()
        try await slots.cancellableWait()
        let startedAt = Date()
        let waitedForSlot = startedAt.timeIntervalSince(queuedAt)

        let service = self.service
        do {
            // Abandoning timeout rather than a task-group race: a group awaits ALL of
            // its children, so a query whose result handler never fires would hang the
            // caller, and with it the sensor's task slot and the observer's completion
            // handler, past the deadline. On timeout the work task is cancelled, which
            // stops the underlying HealthKit query via the service's cancellation
            // handler, and then abandoned.
            let page = try await withAbandoningTimeout(seconds: timeout, operationName: "anchor query") {
                var predicate: NSPredicate?
                if let startDate, let endDate {
                    predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
                }
                return try await service.runAnchorQuery(
                    for: sampleType,
                    predicate: predicate,
                    anchor: anchor,
                    limit: limit
                )
            }
            await slots.signal()
            let duration = AnchoredQueryTimeoutContext.format(Date().timeIntervalSince(startedAt))
            let waited = AnchoredQueryTimeoutContext.format(waitedForSlot)
            Sahha.log("[\(logLabel)] \(sensor.rawValue) page \(pagesCompleted + 1): \(page.0.count) samples in \(duration) (limit \(limit), waited \(waited) for a query slot)")
            return page
        } catch is AsyncTimeoutError {
            let elapsed = Date().timeIntervalSince(startedAt)
            // Read before signalling, so the snapshot counts this page's own slot.
            let load = await slots.load
            await slots.signal()
            let nextLimit = stepDownPageSize(for: sensor, from: limit)
            let appState = await appStateProvider?.snapshot()
            let context = AnchoredQueryTimeoutContext(
                limit: limit,
                nextLimit: nextLimit,
                isInitialSync: anchor == nil,
                pagesCompleted: pagesCompleted,
                elapsed: elapsed,
                waitedForSlot: waitedForSlot,
                slots: load,
                appState: appState
            )
            Sahha.log("[\(logLabel)] \(sensor.rawValue) page \(pagesCompleted + 1) timed out: \(context)")
            throw AnchoredQueryTimeoutError(sensor: sensor, seconds: timeout, context: context)
        } catch {
            await slots.signal()
            throw error
        }
    }

    /// Moves the sensor one size below `limit`, the size that just timed out, and
    /// returns the size its next page will request. Stays put at the smallest size.
    private func stepDownPageSize(for sensor: SahhaSensor, from limit: Int) -> Int {
        let current = pageSizes.firstIndex(of: limit) ?? (pageSizeLevels[sensor] ?? 0)
        let next = min(current + 1, pageSizes.count - 1)
        pageSizeLevels[sensor] = next
        return pageSizes[next]
    }
}
