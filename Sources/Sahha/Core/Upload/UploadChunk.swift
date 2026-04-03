import Foundation

/// A generic chunk of requests ready for upload, parameterized by request type.
struct UploadChunk<Request: UploadableRequest>: Codable, Sendable {
    let requests: [Request]
    let sizeInBytes: Int
    let priority: UploadPriority
}
