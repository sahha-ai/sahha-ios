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
}
