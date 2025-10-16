import HealthKit

protocol HealthKitAnchorStoreProtocol: Actor {
    func saveAnchor(_ anchor: HKQueryAnchor, forKey key: String) throws
    func loadAnchor(forKey key: String) throws -> HKQueryAnchor?
}

extension HealthKitAnchorStoreProtocol {
    func saveAnchor(_ date: HKQueryAnchor, for sensor: SahhaSensor) throws {
        try saveAnchor(date, forKey: sensor.rawValue)
    }
    func loadAnchor(for sensor: SahhaSensor) throws -> HKQueryAnchor? {
        try loadAnchor(forKey: sensor.rawValue)
    }
}
