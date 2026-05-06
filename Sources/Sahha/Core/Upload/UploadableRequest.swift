import Foundation

/// Protocol for request types that can be uploaded through the unified pipeline.
/// Both DataLogRequest and TagRequest conform to this protocol.
protocol UploadableRequest: Codable, Sendable {
    var id: String { get }
}
