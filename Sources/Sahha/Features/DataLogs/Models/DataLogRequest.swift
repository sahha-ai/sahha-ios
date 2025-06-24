struct DataLogRequest: Codable, Sendable {
    var id: String
    var parentId: String?
    var logType: String
    var dataType: String
    var value: Double
    var unit: String
    var source: String
    var recordingMethod: String
    var deviceId: String
    var deviceType: String
    var startDateTime: String
    var endDateTime: String
    var postDateTime: String
    var additionalProperties: String?
}
