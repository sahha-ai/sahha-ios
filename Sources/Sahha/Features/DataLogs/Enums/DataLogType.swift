enum DataLogType: Int, Codable {
    case demographic
    case sleep
    case activity
    case device
    case heart
    case blood
    case oxygen
    case energy
    case temperature
    case body
    case exercise
    case nutrition
    case reproductive
    case symptom

    /// The wire logType stamped on uploaded DataLogs and the `category` label returned
    /// by getStats/getSamples — renaming a case changes both, so case names are load-bearing.
    var stringValue: String { String(describing: self) }
}
