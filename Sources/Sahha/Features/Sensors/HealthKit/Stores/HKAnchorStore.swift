import HealthKit

protocol HKAnchorStore: Actor, Disposable {
    func loadAnchor(for key: String) throws -> HKQueryAnchor?
    func saveAnchor(_ anchor: HKQueryAnchor, for key: String) throws
}
