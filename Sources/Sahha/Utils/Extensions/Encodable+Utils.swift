import Foundation

extension Encodable {
    func toJsonString(named typeName: String = String(describing: Self.self)) throws -> String {
        do {
            let encoded = try JSONEncoder().encode(self)
            guard let json = String(data: encoded, encoding: .utf8) else {
                throw SahhaError.custom(message: "Failed to encode JSON string for \(typeName).")
            }
            return json
        } catch {
            throw SahhaError.custom(message: "Failed to encode \(typeName): \(error.localizedDescription)")
        }
    }
}
