import Foundation

struct DeviceInfoCacheState: Codable, Sendable {
    let hash: String
    let lastFetch: Date
}
