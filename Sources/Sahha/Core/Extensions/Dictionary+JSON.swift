import Foundation

extension Dictionary where Key == String, Value == String {
    func toJSONString() -> String? {
        if let data = try? JSONSerialization.data(withJSONObject: self, options: []) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
