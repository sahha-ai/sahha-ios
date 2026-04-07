import HealthKit

actor HealthKitObserverStore: HealthKitObserverStoreProtocol {
    private var observers: [String: HKObserverQuery] = [:]

    func addObserver(_ observer: HKObserverQuery, forKey key: String) {
        observers[key] = observer
    }

    func removeObserver(forKey key: String) -> HKObserverQuery? {
        observers.removeValue(forKey: key)
    }

    func removeAllObservers() -> [HKObserverQuery] {
        defer { observers.removeAll() }
        return Array(observers.values)
    }

    func getRegisteredKeys() -> Set<String> {
        Set(observers.keys)
    }
}
