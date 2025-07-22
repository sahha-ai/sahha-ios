enum LogType: Int, Codable {
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

    var stringValue: String { String(describing: self) }
}
