import HealthKit

actor HealthKitObserverStore: HealthKitObserverStoreProtocol {
    private var observers: [String: HKObserverQuery] = [:]

    func addObserver(_ observer: HKObserverQuery, forKey key: String) {
        observers[key] = observer
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
}
