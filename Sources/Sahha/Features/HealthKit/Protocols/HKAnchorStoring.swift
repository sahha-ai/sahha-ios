import HealthKit

protocol HKAnchorStoring: Actor, Disposable {
    func saveAnchor(_ anchor: HKQueryAnchor, for key: String) async throws
    func loadAnchor(for key: String) async throws -> HKQueryAnchor?
    func deleteAnchor(for key: String) async
    func deleteAllAnchors() async
}
