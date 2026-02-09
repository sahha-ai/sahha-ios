import Foundation

extension Array where Element: Encodable {
    /// Returns a JSON string representation of this array.
    func toJSONString() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "Failed to encode array as JSON string"))
        }
        return jsonString
    }
}
