import Foundation

struct DemographicCacheState: Codable, Sendable {
    let hash: String
    let lastFetch: Date
}
