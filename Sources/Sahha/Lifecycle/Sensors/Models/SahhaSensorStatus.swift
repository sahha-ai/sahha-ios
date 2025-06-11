public enum SahhaSensorStatus: String, Sendable, CustomStringConvertible {
    case pending, unavailable, disabled, enabled

    public var description: String {
        rawValue.capitalized
    }
}
