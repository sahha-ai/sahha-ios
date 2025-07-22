import Foundation

protocol DemographicCaching: Actor, Disposable {
    func get() -> SahhaDemographic?
    func set(_ demographic: SahhaDemographic) async
    func isValid(ttl: TimeInterval) -> Bool
    func needsSync(with demographic: SahhaDemographic) async -> Bool
    func clear() async
}
