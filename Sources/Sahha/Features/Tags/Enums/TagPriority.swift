/// Upload priority levels for tag delivery
enum TagPriority: Int, Codable, Sendable, Comparable, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: TagPriority, rhs: TagPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

protocol TagPriorityAssignerProtocol: Sendable {
    func assignPriority(to tag: Tag) -> TagPriority
}
