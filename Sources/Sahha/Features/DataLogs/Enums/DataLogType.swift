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

    var stringValue: String { String(describing: self) }
}
