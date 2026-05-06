protocol UploadPriorityAssignerProtocol: Sendable {
    func assignPriority(to log: DataLog) -> UploadPriority
}
