import Foundation

protocol DeviceInfoCaching: Actor {
    func set(_ info: DeviceInformation) async
    func isValid(ttl: TimeInterval) -> Bool
    func needsSync(with info: DeviceInformation) async -> Bool
}
