public enum SahhaSensorStatus: Int {
    case pending
    case unavailable
    case disabled
    case enabled

    public var description: String {
        String(describing: self)
    }
}
