public enum SahhaSensorStatus: String, Sendable {
    case pending /// Sensor data is pending User permission
    case unavailable /// Sensor data is not supported by the User's device
    case disabled /// Sensor data has been disabled by the User
    case enabled /// Sensor data has been enabled by the User
    public var description: String {
        String(describing: self)
    }
}