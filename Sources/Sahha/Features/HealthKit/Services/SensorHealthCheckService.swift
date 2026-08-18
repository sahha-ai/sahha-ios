import Foundation

/// Runs the sensor health check (PRD #76 D11): detects enabled sensors whose
/// observer query or background delivery has gone missing, repairs exactly what
/// is missing, and posts one aggregate error for anything it could not repair.
protocol SensorHealthCheckServiceProtocol: Sendable {
    @discardableResult
    func runHealthCheck() async -> SensorHealthCheckResult
    func getLatestResult() async -> SensorHealthCheckResult?
}

actor SensorHealthCheckService: SensorHealthCheckServiceProtocol {
    private let sensorStore: SensorStoreProtocol
    private let observerStore: HealthKitObserverStoreProtocol
    private let healthKitManager: HealthKitManagerProtocol
    private let observerService: HealthKitObserverServiceProtocol
    private let logger: ErrorLoggerProtocol

    private var inFlight: Task<SensorHealthCheckResult, Never>?
    private var latestResult: SensorHealthCheckResult?

    init(
        sensorStore: SensorStoreProtocol,
        observerStore: HealthKitObserverStoreProtocol,
        healthKitManager: HealthKitManagerProtocol,
        observerService: HealthKitObserverServiceProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.sensorStore = sensorStore
        self.observerStore = observerStore
        self.healthKitManager = healthKitManager
        self.observerService = observerService
        self.logger = logger
    }

    /// Single-flight: the lifecycle bus can dispatch overlapping checks, and the
    /// bring-up tail adds another trigger — a check arriving while one is running
    /// joins the running pass instead of starting a second re-arm.
    func runHealthCheck() async -> SensorHealthCheckResult {
        if let inFlight {
            return await inFlight.value
        }
        let task = Task { await self.performHealthCheck() }
        inFlight = task
        let result = await task.value
        latestResult = result
        inFlight = nil
        return result
    }

    func getLatestResult() -> SensorHealthCheckResult? {
        latestResult
    }

    private func performHealthCheck() async -> SensorHealthCheckResult {
        let enabledSensors: Set<SahhaSensor>
        do {
            enabledSensors = try await sensorStore.getSensors()
        } catch {
            // An unreadable store blinds the entire check — previously swallowed,
            // which made a broken store indistinguishable from a healthy empty one.
            logger.postError(error)
            return SensorHealthCheckResult(
                timestamp: Date(),
                sensorsChecked: [],
                sensorsReRegistered: [],
                failures: [:]
            )
        }

        guard !enabledSensors.isEmpty else {
            return SensorHealthCheckResult(
                timestamp: Date(),
                sensorsChecked: [],
                sensorsReRegistered: [],
                failures: [:]
            )
        }

        // "Missing" is (no observer) ∪ (no delivery record), restricted to
        // sample-type-backed sensors — the only ones that ever hold an observer.
        // A registered observer whose delivery iOS has silently suspended is an
        // accepted blind spot: it cannot be detected in-process.
        let sampleBacked = enabledSensors.filter { $0.hkSampleType != nil }
        let registeredKeys = await observerStore.getRegisteredKeys()
        let deliveryKeys = await observerStore.getDeliveryEnabledKeys()
        let missingObserver = sampleBacked.filter { !registeredKeys.contains($0.rawValue) }
        let missingDeliveryOnly = sampleBacked.filter {
            registeredKeys.contains($0.rawValue) && !deliveryKeys.contains($0.rawValue)
        }

        var reRegistered = Set<SahhaSensor>()
        var failures: [SahhaSensor: String] = [:]
        let repairTargets = missingObserver.union(missingDeliveryOnly)

        if !missingObserver.isEmpty {
            Sahha.log("[SensorHealthCheck] Missing observers for: \(missingObserver.map(\.rawValue).sorted().joined(separator: ", "))")
            // Bounded re-arm: only the sensors that are actually missing, through
            // the set-scoped entry point (which intersects with a fresh store read
            // at arm time and arms each side independently).
            await healthKitManager.resumeSensors(for: missingObserver)
        }

        if !missingDeliveryOnly.isEmpty {
            Sahha.log("[SensorHealthCheck] Missing background delivery for: \(missingDeliveryOnly.map(\.rawValue).sorted().joined(separator: ", "))")
            do {
                // A sensor missing only its delivery gets the delivery call alone —
                // never a second observer query. Re-enabling an already-enabled
                // type is a documented-safe frequency replace.
                try await observerService.enableBackgroundDelivery(for: missingDeliveryOnly)
            } catch {
                // Which sensors stayed broken is decided by the verification
                // below; the aggregate there carries their names.
                Sahha.log("[SensorHealthCheck] Delivery repair failed: \(error)")
            }
        }

        if !repairTargets.isEmpty {
            // Verify against the store's post-repair state. Sensors disabled by a
            // concurrent narrowing enableSensors since the check started are not
            // failures — they no longer need arming at all.
            let currentlyEnabled = (try? await sensorStore.getSensors()) ?? enabledSensors
            let updatedRegistered = await observerStore.getRegisteredKeys()
            let updatedDelivery = await observerStore.getDeliveryEnabledKeys()

            for sensor in repairTargets where currentlyEnabled.contains(sensor) {
                if updatedRegistered.contains(sensor.rawValue), updatedDelivery.contains(sensor.rawValue) {
                    reRegistered.insert(sensor)
                } else {
                    failures[sensor] = "Observer re-registration failed for \(sensor.rawValue)"
                }
            }

            if !failures.isEmpty {
                // One aggregate post carrying the count and every failed sensor:
                // per-sensor posts would be collapsed by the logger's origin-keyed
                // dedup into whichever sensor happened to post first.
                let names = failures.keys.map(\.rawValue).sorted().joined(separator: ", ")
                logger.postError(SahhaError(
                    message: "Observer re-registration failed for \(failures.count) sensor(s): \(names)"
                ))
            }
        }

        return SensorHealthCheckResult(
            timestamp: Date(),
            sensorsChecked: enabledSensors,
            sensorsReRegistered: reRegistered,
            failures: failures
        )
    }
}
