struct BiomarkerResponse: Codable {
    let id: String
    let category: String
    let type: String
    let periodicity: String
    let aggregation: String
    let value: String
    let unit: String
    let valueType: String
    let startDateTime: String
    let endDateTime: String
}
