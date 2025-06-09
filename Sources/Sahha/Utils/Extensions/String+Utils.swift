import Foundation

extension String {
    func jwtExpirationDate() -> Date? {
        let parts = self.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        let payloadBase64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let paddedBase64 = payloadBase64.padding(
            toLength: ((payloadBase64.count + 3) / 4) * 4,
            withPad: "=",
            startingAt: 0
        )
        
        guard let data = Data(base64Encoded: paddedBase64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        
        return Date(timeIntervalSince1970: exp)
    }
    
    var camelToSnake: String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(startIndex..., in: self)
        let modified = regex?.stringByReplacingMatches(
            in: self,
            options: [],
            range: range,
            withTemplate: "$1_$2"
        ) ?? self
        return modified.lowercased()
    }
}
