/// Shared priority levels for upload delivery across all data types.
enum UploadPriority: Int, Codable, Sendable, Comparable, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: UploadPriority, rhs: UploadPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
