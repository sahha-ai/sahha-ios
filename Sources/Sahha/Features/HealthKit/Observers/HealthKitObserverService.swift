import HealthKit

final class HealthKitObserverService: HealthKitObserverServiceProtocol {
    private let healthStore: HKHealthStore
    private let observerStore: HealthKitObserverStoreProtocol
    private let circuitBreaker: CircuitBreaker?
    private let backgroundTasks: BackgroundTaskProviding
    private let logger: ErrorLoggerProtocol

    init(
        healthStore: HKHealthStore = .init(),
        observerStore: HealthKitObserverStoreProtocol,
        circuitBreaker: CircuitBreaker? = nil,
        backgroundTasks: BackgroundTaskProviding = UIKitBackgroundTaskProvider(),
        logger: ErrorLoggerProtocol
    ) {
        self.healthStore = healthStore
        self.observerStore = observerStore
        self.circuitBreaker = circuitBreaker
        self.backgroundTasks = backgroundTasks
        self.logger = logger
    }
    
    func startObservers(for sensors: Set<SahhaSensor>, handler: @escaping HealthKitObserverHandler) async throws {
        Sahha.log("[HealthKitObserver] startObservers called for \(sensors.count) sensors: \(sensors.map(\.rawValue).sorted())")
        for sensor in sensors {
            // Per-sensor isolation: a failure for one sensor does not prevent others from registering
            do {
                try await startObserver(for: sensor, handler: handler)
            } catch {
                Sahha.log("[HealthKitObserver] Failed to register observer for \(sensor.rawValue): \(error.localizedDescription)")
                logger.postError(error)
            }
        }
        let keys = await observerStore.getRegisteredKeys()
        Sahha.log("[HealthKitObserver] After startObservers, registered keys: \(keys.sorted())")
    }

    private func startObserver(for sensor: SahhaSensor, handler: @escaping HealthKitObserverHandler) async throws {
        // Register observers for ALL enabled sensors regardless of permission status.
        // An idle observer for a denied sensor has negligible resource cost and
        // automatically catches late permission grants via iOS Settings > Health.
        guard let sampleType = sensor.hkSampleType else { return }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completion, error in
            if error != nil {
                completion()
            } else {
                let wrappedCompletion = SendableCompletion(run: completion)

                Task {
                    guard let self else {
                        wrappedCompletion.run()
                        return
                    }
                    await self.handleUpdate(
                        for: sensor,
                        sampleType: sampleType,
                        completion: { wrappedCompletion.run() },
                        handler: handler
                    )
                }
            }
        }
        // Atomic replace: if this sensor already has an executing observer (a
        // repeated enableSensors, or two arms racing), the displaced query is
        // stopped in the same store turn that registers and executes the new one.
        let healthStore = self.healthStore
        await observerStore.replaceObserver(
            query,
            for: sensor,
            stoppingDisplaced: { healthStore.stop($0) },
            executing: { healthStore.execute($0) }
        )
    }
    
    /// Runs one observer update under a UIKit background task, then calls
    /// HealthKit's completion handler and ends the task.
    ///
    /// Internal rather than private so tests can drive an update directly: an
    /// `HKObserverQuery`'s update handler cannot be invoked from outside HealthKit.
    func handleUpdate(
        for sensor: SahhaSensor,
        sampleType: HKSampleType,
        completion: @escaping @Sendable () -> Void,
        handler: HealthKitObserverHandler
    ) async {
        // HealthKit's completion handler is the lease's `onEnd`, so it runs
        // exactly once, with whichever ends the background task first: this run
        // finishing, or the expiration handler when background time runs out
        // mid-run (slow anchored-query pages, or a wait for a query slot).
        //
        // Calling it at expiry, before the run has finished, is deliberate. It
        // tells HealthKit the update was received and commits nothing: the
        // anchor advances only as pages are saved, so whatever this run has not
        // fetched is picked up from the saved anchor when the run resumes or on
        // the next trigger. Leaving it uncalled while the app suspends is what
        // HealthKit holds against the app: it relaunches the app with backoff
        // and, after three unanswered updates, stops sending it background
        // updates. A run that outlasts its background time once tends to do so
        // again, so holding the call back would turn a slow sensor into a
        // silent one.
        let backgroundTask = await BackgroundTaskLease.begin(
            named: "Sahha.HealthKit.\(sensor.rawValue)",
            provider: backgroundTasks,
            onEnd: completion
        )

        if let circuitBreaker, !(await circuitBreaker.isHealthy()) {
            let (state, _) = await circuitBreaker.getState()
            Sahha.log("[HealthKitObserver] Skipping query for \(sensor.rawValue) - circuit breaker is \(state)")
        } else {
            Sahha.log("[HealthKitObserver] Background delivery triggered for \(sensor.rawValue)")
            await handler(sensor, sampleType)
            Sahha.log("[HealthKitObserver] Background delivery completed for \(sensor.rawValue)")
        }

        await backgroundTask.end()
    }

    private struct SendableCompletion: @unchecked Sendable {
        let run: () -> Void
    }
    
    func stopObservers(for sensors: Set<SahhaSensor>) async throws {
        for sensor in sensors {
            try await stopObserver(for: sensor)
        }
    }

    private func stopObserver(for sensor: SahhaSensor) async throws {
        if let query = await observerStore.removeObserver(for: sensor) {
            healthStore.stop(query)
        }
    }
    
    func enableBackgroundDelivery(for sensors: Set<SahhaSensor>) async throws {
        // Per-sensor isolation: one denied type must not abort the rest of the
        // (unordered) loop. Each success is recorded in the observer store so the
        // health check can later re-enable exactly the sensors whose delivery is
        // missing; the failures surface once, aggregated, after every sensor has
        // been attempted.
        var failed: [SahhaSensor: Error] = [:]
        for sensor in sensors {
            guard let sampleType = sensor.hkSampleType else { continue }
            do {
                try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
                await observerStore.recordDeliveryEnabled(for: sensor)
            } catch {
                failed[sensor] = error
            }
        }
        if !failed.isEmpty {
            let failures = failed.sorted { $0.key.rawValue < $1.key.rawValue }
            throw SahhaError(
                message: "Background delivery could not be enabled for \(failures.count) sensor(s): \(failures.map(\.key.rawValue).joined(separator: ", "))",
                error: failures.first?.value
            )
        }
    }

    func disableBackgroundDelivery(for sensors: Set<SahhaSensor>) async throws {
        // The delivery record is dropped whether or not the disable call succeeds:
        // a record without a live enable would only hide the sensor from the
        // health check, whereas re-enabling an already-enabled type is a
        // documented-safe frequency replace.
        var failed: [SahhaSensor: Error] = [:]
        for sensor in sensors {
            guard let sampleType = sensor.hkSampleType else { continue }
            await observerStore.removeDeliveryRecord(for: sensor)
            do {
                try await healthStore.disableBackgroundDelivery(for: sampleType)
            } catch {
                failed[sensor] = error
            }
        }
        if !failed.isEmpty {
            let failures = failed.sorted { $0.key.rawValue < $1.key.rawValue }
            throw SahhaError(
                message: "Background delivery could not be disabled for \(failures.count) sensor(s): \(failures.map(\.key.rawValue).joined(separator: ", "))",
                error: failures.first?.value
            )
        }
    }
    
    func dispose() async {
        await stopAllObservers()
        await disableAllBackgroundDeliveries()
    }

    private func stopAllObservers() async {
        for query in await observerStore.removeAllObservers() {
            healthStore.stop(query)
        }
    }

    private func disableAllBackgroundDeliveries() async {
        await observerStore.removeAllDeliveryRecords()
        do {
            try await healthStore.disableAllBackgroundDelivery()
        } catch {
        }
    }
}


