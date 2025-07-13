import Foundation

struct JWTDecoder: Sendable {
    private enum DecodeError: Error, LocalizedError {
        case malformed
        case badBase64
        case badJSON

        var errorDescription: String? {
            switch self {
            case .malformed: return "Malformed JWT"
            case .badBase64: return "Invalid Base64 encoding"
            case .badJSON: return "Invalid JSON payload"
            }
        }
    }

    func decodePayload(from jwt: String) throws -> [String: Any] {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { throw DecodeError.malformed }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64.append(String(repeating: "=", count: (4 - base64.count % 4) % 4))

        guard let data = Data(base64Encoded: base64) else { throw DecodeError.badBase64 }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw DecodeError.badJSON }

        return json
    }

    func expiryDate(from jwt: String) -> Date? {
        (try? decodePayload(from: jwt))?["exp"].flatMap {
            if let ts = $0 as? Double { return Date(timeIntervalSince1970: ts) }
            if let ts = $0 as? Int { return Date(timeIntervalSince1970: TimeInterval(ts)) }
            return nil
        }
    }
}
