import Foundation

extension Encodable {
    func sha256Hash(using encoder: JSONEncoder = JSONEncoder()) throws -> String {
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(self)
        return data.sha256Hex()
    }
}
