import Foundation

struct JWT {
    static func profileId(from jwt: String) -> String? {
        guard let json = decodePayload(jwt) else { return nil }
        return json["https://api.sahha.ai/claims/profileId"] as? String
    }

    static func expiryDate(from jwt: String) -> Date? {
        guard let json = decodePayload(jwt),
            let exp = json["exp"] as? Double
        else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    private static func decodePayload(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3,
            let payloadData = Data(base64Encoded: String(parts[1]).base64UrlToBase64()),
            let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else { return nil }
        return json
    }

    static func isExpired(_ jwt: String, offset: TimeInterval = 0) -> Bool {
        guard let expiry = expiryDate(from: jwt) else { return true }
        let adjustedExpiry = expiry.addingTimeInterval(-offset)
        return adjustedExpiry <= Date()
    }
}

extension String {
    fileprivate func base64UrlToBase64() -> String {
        var base64 = self
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }
        return base64
    }
}
