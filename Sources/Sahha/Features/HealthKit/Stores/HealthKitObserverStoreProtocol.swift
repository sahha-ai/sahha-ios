import HealthKit

protocol HealthKitObserverStoreProtocol: Actor {
    func addObserver(_ observer: HKObserverQuery, forKey key: String)
    func removeObserver(forKey key: String) -> HKObserverQuery?
    func removeAllObservers() -> [HKObserverQuery]
    func getRegisteredKeys() -> Set<String>
}

extension HealthKitObserverStoreProtocol {
    func addObserver(_ observer: HKObserverQuery, for sensor: SahhaSensor) {
        addObserver(observer, forKey: sensor.rawValue)
    }
    func removeObserver(for sensor: SahhaSensor) -> HKObserverQuery? {
        removeObserver(forKey: sensor.rawValue)
    }
}
