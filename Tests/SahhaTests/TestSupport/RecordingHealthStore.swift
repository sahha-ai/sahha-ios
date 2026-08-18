import Foundation
import HealthKit

/// Recording `HKHealthStore` double covering the surfaces the SDK drives:
/// authorization requests (immediate or captured-and-released), authorization
/// status, query execute/stop, and background delivery. Consolidates the
/// per-file stores that previously lived in NonHealthKitSensorPermissionsTests,
/// EnableSensorsTimeoutTests and SahhaTests.
final class RecordingHealthStore: HKHealthStore, @unchecked Sendable {
    private let lock = NSLock()

    // MARK: - Authorization requests

    private var _autoComplete: Bool
    private var _authorizationRequests: [Set<HKObjectType>] = []
    private var pendingCompletions: [(Bool, Error?) -> Void] = []
    private var completedCount = 0

    /// When true (the default), authorization requests complete immediately with
    /// (true, nil); when false they park until `completeNext()` — the
    /// "permission sheet never resolves" mode.
    var autoComplete: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _autoComplete }
        set { lock.lock(); defer { lock.unlock() }; _autoComplete = newValue }
    }

    /// Read type-sets passed to `requestAuthorization`, in order.
    var authorizationRequests: [Set<HKObjectType>] {
        lock.lock(); defer { lock.unlock() }
        return _authorizationRequests
    }

    /// Authorization requests that reached the store (parked + completed).
    var capturedCompletionCount: Int {
        lock.lock(); defer { lock.unlock() }
        return pendingCompletions.count + completedCount
    }

    init(autoComplete: Bool = true) {
        self._autoComplete = autoComplete
        super.init()
    }

    override func requestAuthorization(
        toShare typesToShare: Set<HKSampleType>?,
        read typesToRead: Set<HKObjectType>?,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        lock.lock()
        _authorizationRequests.append(typesToRead ?? [])
        let completeNow = _autoComplete
        if completeNow {
            completedCount += 1
        } else {
            pendingCompletions.append(completion)
        }
        lock.unlock()
        if completeNow {
            completion(true, nil)
        }
    }

    /// Completes the oldest parked authorization request.
    func completeNext(success: Bool = true, error: Error? = nil) {
        lock.lock()
        guard !pendingCompletions.isEmpty else {
            lock.unlock()
            return
        }
        let completion = pendingCompletions.removeFirst()
        completedCount += 1
        lock.unlock()
        completion(success, error)
    }

    // MARK: - Authorization status

    private var _statusToReturn: HKAuthorizationRequestStatus = .unnecessary
    private var _statusRequests: [Set<HKObjectType>] = []

    var statusToReturn: HKAuthorizationRequestStatus {
        get { lock.lock(); defer { lock.unlock() }; return _statusToReturn }
        set { lock.lock(); defer { lock.unlock() }; _statusToReturn = newValue }
    }

    /// Read type-sets passed to `getRequestStatusForAuthorization`, in order.
    var statusRequests: [Set<HKObjectType>] {
        lock.lock(); defer { lock.unlock() }
        return _statusRequests
    }

    override func getRequestStatusForAuthorization(
        toShare typesToShare: Set<HKSampleType>,
        read typesToRead: Set<HKObjectType>,
        completion: @escaping (HKAuthorizationRequestStatus, Error?) -> Void
    ) {
        lock.lock()
        _statusRequests.append(typesToRead)
        let status = _statusToReturn
        lock.unlock()
        completion(status, nil)
    }

    // MARK: - Queries

    private var _executedQueries: [HKQuery] = []
    private var _stoppedQueries: [HKQuery] = []

    var executedQueries: [HKQuery] {
        lock.lock(); defer { lock.unlock() }
        return _executedQueries
    }

    var stoppedQueries: [HKQuery] {
        lock.lock(); defer { lock.unlock() }
        return _stoppedQueries
    }

    override func execute(_ query: HKQuery) {
        lock.lock(); defer { lock.unlock() }
        _executedQueries.append(query)
    }

    override func stop(_ query: HKQuery) {
        lock.lock(); defer { lock.unlock() }
        _stoppedQueries.append(query)
    }

    // MARK: - Background delivery

    private var _backgroundDeliveryError: Error?
    private var _failingBackgroundTypes: Set<HKObjectType> = []
    private var _enabledBackgroundTypes: [HKObjectType] = []
    private var _disabledBackgroundTypes: [HKObjectType] = []
    private var _disableAllBackgroundDeliveryCount = 0

    /// When set, enable/disable background-delivery calls report this error.
    var backgroundDeliveryError: Error? {
        get { lock.lock(); defer { lock.unlock() }; return _backgroundDeliveryError }
        set { lock.lock(); defer { lock.unlock() }; _backgroundDeliveryError = newValue }
    }

    /// Per-type scripting: enable-background-delivery calls for these types fail
    /// while every other type succeeds — the "one denied type" scenario.
    var failingBackgroundTypes: Set<HKObjectType> {
        get { lock.lock(); defer { lock.unlock() }; return _failingBackgroundTypes }
        set { lock.lock(); defer { lock.unlock() }; _failingBackgroundTypes = newValue }
    }

    var enabledBackgroundTypes: [HKObjectType] {
        lock.lock(); defer { lock.unlock() }
        return _enabledBackgroundTypes
    }

    var disabledBackgroundTypes: [HKObjectType] {
        lock.lock(); defer { lock.unlock() }
        return _disabledBackgroundTypes
    }

    var disableAllBackgroundDeliveryCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _disableAllBackgroundDeliveryCount
    }

    override func enableBackgroundDelivery(
        for type: HKObjectType,
        frequency: HKUpdateFrequency,
        withCompletion completion: @escaping (Bool, Error?) -> Void
    ) {
        lock.lock()
        _enabledBackgroundTypes.append(type)
        var error = _backgroundDeliveryError
        if error == nil, _failingBackgroundTypes.contains(type) {
            error = NSError(domain: "RecordingHealthStore.backgroundDelivery", code: 1)
        }
        lock.unlock()
        completion(error == nil, error)
    }

    override func disableBackgroundDelivery(
        for type: HKObjectType,
        withCompletion completion: @escaping (Bool, Error?) -> Void
    ) {
        lock.lock()
        _disabledBackgroundTypes.append(type)
        let error = _backgroundDeliveryError
        lock.unlock()
        completion(error == nil, error)
    }

    override func disableAllBackgroundDelivery(
        completion: @escaping (Bool, Error?) -> Void
    ) {
        lock.lock()
        _disableAllBackgroundDeliveryCount += 1
        let error = _backgroundDeliveryError
        lock.unlock()
        completion(error == nil, error)
    }
}
