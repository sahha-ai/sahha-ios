import Foundation

enum JWTDecoder {
    static func decodeExp(jwt: String) -> Double? {
        let segments = jwt.split(separator: ".")
        guard segments.count == 3 else { return nil }
        
        guard let payloadData = decodeBase64URL(String(segments[1])) else { return nil }
        
        guard let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? Double else { return nil }
        
        return exp
    }
    
    private static func decodeBase64URL(_ string: String) -> Data? {
        let padded = string + String(repeating: "=", count: (4 - string.count % 4) % 4)
        let base64 = padded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        return Data(base64Encoded: base64)
    }
}
