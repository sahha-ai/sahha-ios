import Foundation

extension Array where Element: Encodable {
    /// Returns a JSON string with this array wrapped in a top-level "data" key.
    func toDataWrappedJSONString() throws -> String {
        let wrapper = ["data": self]
        let data = try JSONEncoder().encode(wrapper)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "Failed to encode array as JSON string"))
        }
        return jsonString
    }
}
