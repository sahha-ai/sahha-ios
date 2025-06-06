public enum SahhaSensorStatus: Int, Sendable, CustomStringConvertible {
    case pending
    case unavailable
    case disabled
    case enabled

    public var description: String {
        String(describing: self)
    }
}
