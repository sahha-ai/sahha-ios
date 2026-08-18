import HealthKit

actor HealthKitObserverStore: HealthKitObserverStoreProtocol {
    private var observers: [String: HKObserverQuery] = [:]
    private var deliveryEnabledKeys: Set<String> = []

    func replaceObserver(
        _ observer: HKObserverQuery,
        forKey key: String,
        stoppingDisplaced stop: (HKObserverQuery) -> Void,
        executing execute: (HKObserverQuery) -> Void
    ) {
        // Stop-displaced → store → execute with no suspension point between the
        // three, so `executed − stopped == registered` holds across arbitrary
        // concurrent re-arms and a displaced query can never keep running.
        if let displaced = observers[key] {
            stop(displaced)
        }
        observers[key] = observer
        execute(observer)
    }

    func removeObserver(forKey key: String) -> HKObserverQuery? {
        Sahha.log("[HealthKitObserverStore] removeObserver for key: \(key). Thread: \(Thread.current)")
        return observers.removeValue(forKey: key)
    }

    func removeAllObservers() -> [HKObserverQuery] {
        Sahha.log("[HealthKitObserverStore] removeAllObservers called (\(observers.count) observers). Thread: \(Thread.current)")
        Thread.callStackSymbols.prefix(10).forEach { Sahha.log("  \($0)") }
        defer { observers.removeAll() }
        return Array(observers.values)
    }

    func getRegisteredKeys() -> Set<String> {
        Set(observers.keys)
    }

    func recordDeliveryEnabled(forKey key: String) {
        deliveryEnabledKeys.insert(key)
    }

    func removeDeliveryRecord(forKey key: String) {
        deliveryEnabledKeys.remove(key)
    }

    func removeAllDeliveryRecords() {
        deliveryEnabledKeys.removeAll()
    }

    func getDeliveryEnabledKeys() -> Set<String> {
        deliveryEnabledKeys
    }
}
