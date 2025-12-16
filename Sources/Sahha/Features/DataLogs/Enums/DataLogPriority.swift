enum UploadPriority: Int, Codable, Comparable {
    case low = 0      
    case normal = 1   
    case high = 2     
    case critical = 3 
    
    static func < (lhs: UploadPriority, rhs: UploadPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

protocol UploadPriorityAssignerProtocol: Sendable {
    func assignPriority(to log: DataLog) -> UploadPriority
}
