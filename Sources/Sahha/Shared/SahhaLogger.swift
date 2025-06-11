import Foundation

enum SahhaLogLevel: String {
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
}

final class SahhaLogger {
    
    static func info(_ message: @autoclosure () -> String) {
        log(.info, message())
    }

    static func warning(_ message: @autoclosure () -> String) {
        log(.warning, message())
    }

    static func error(_ message: @autoclosure () -> String) {
        log(.error, message())
    }

    private static func log(_ level: SahhaLogLevel, _ message: @autoclosure () -> String) {
#if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[Sahha] \(timestamp) \(level.rawValue): \(message())")
#endif
    }
}
