import Foundation

extension Array where Element: Encodable {
    private struct DataWrapper: Encodable {
        let data: [Element]
    }
    
    func toDataWrappedJSON() throws -> String {
        let wrapper = DataWrapper(data: self)
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(wrapper)
        return String(data: jsonData, encoding: .utf8)!
    }
}
