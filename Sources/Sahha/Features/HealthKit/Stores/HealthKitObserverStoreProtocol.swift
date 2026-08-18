import HealthKit

protocol HealthKitObserverStoreProtocol: Actor {
    /// Atomically replaces the observer registered under `key`: the displaced
    /// query (if any) is stopped, the new query is stored, and the new query is
    /// executed — all inside one synchronous actor turn, so no interleaving can
    /// leave a query executing outside the store. This is what makes orphaned
    /// observer queries impossible across concurrent or repeated arming.
    func replaceObserver(
        _ observer: HKObserverQuery,
        forKey key: String,
        stoppingDisplaced stop: (HKObserverQuery) -> Void,
        executing execute: (HKObserverQuery) -> Void
    )
    func removeObserver(forKey key: String) -> HKObserverQuery?
    func removeAllObservers() -> [HKObserverQuery]
    func getRegisteredKeys() -> Set<String>

    /// Background-delivery bookkeeping: a key is recorded when
    /// `enableBackgroundDelivery` last succeeded for that sensor, so the health
    /// check can distinguish a sensor missing only its delivery (repairable with
    /// a lone re-enable) from one missing its observer (needs a full re-arm).
    func recordDeliveryEnabled(forKey key: String)
    func removeDeliveryRecord(forKey key: String)
    func removeAllDeliveryRecords()
    func getDeliveryEnabledKeys() -> Set<String>
}

extension HealthKitObserverStoreProtocol {
    func replaceObserver(
        _ observer: HKObserverQuery,
        for sensor: SahhaSensor,
        stoppingDisplaced stop: (HKObserverQuery) -> Void,
        executing execute: (HKObserverQuery) -> Void
    ) {
        replaceObserver(observer, forKey: sensor.rawValue, stoppingDisplaced: stop, executing: execute)
    }
    func removeObserver(for sensor: SahhaSensor) -> HKObserverQuery? {
        removeObserver(forKey: sensor.rawValue)
    }
    func recordDeliveryEnabled(for sensor: SahhaSensor) {
        recordDeliveryEnabled(forKey: sensor.rawValue)
    }
    func removeDeliveryRecord(for sensor: SahhaSensor) {
        removeDeliveryRecord(forKey: sensor.rawValue)
    }
}
