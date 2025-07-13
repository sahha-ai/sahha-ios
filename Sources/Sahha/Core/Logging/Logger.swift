import Foundation

enum LogLevel: Int, Codable, Sendable, Comparable {
    case info = 0
    case warning = 1
    case error = 2
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

protocol Logger: AnyObject, Sendable {
    nonisolated func log(
        _ level: LogLevel,
        _ message: @autoclosure @escaping @Sendable () -> String,
        context: LoggerContext
    )
}

final actor LoggerImpl: Logger {
    private let service: LoggingService
    private let deviceInfo: DeviceInformation
    private let minLevel: LogLevel

    init(
        service: LoggingService,
        deviceInfo: DeviceInformation,
        minLevel: LogLevel = .info
    ) {
        self.service = service
        self.deviceInfo = deviceInfo
        self.minLevel = minLevel
    }

    nonisolated func log(
        _ level: LogLevel,
        _ message: @autoclosure @escaping @Sendable () -> String,
        context: LoggerContext
    ) {
        Task { await record(level, message(), context: context) }
    }

    private func record(
        _ level: LogLevel,
        _ message: String,
        context: LoggerContext
    ) {

        guard level >= minLevel else { return }

        #if DEBUG
            print("[\(level)] \(message)")
        #endif

        guard level == .error else { return }

        let error = ErrorRequest(
            sdkId: deviceInfo.sdkId,
            sdkVersion: deviceInfo.sdkVersion,
            appId: deviceInfo.appId,
            appVersion: deviceInfo.appVersion,
            deviceId: deviceInfo.deviceId,
            deviceType: deviceInfo.deviceType,
            deviceModel: deviceInfo.deviceModel,
            system: deviceInfo.system,
            systemVersion: deviceInfo.systemVersion,
            errorSource: context.sourceString,
            errorCode: context.errorCode,
            errorLocation: context.errorLocation,
            errorMessage: message,
            errorBody: context.errorBody,
            codePath: context.codePath,
            codeMethod: context.codeMethod,
            codeBody: context.codeBody
        )

        Task.detached(priority: .background) {
            do {
                try await self.service.postError(error)
            } catch {
                #if DEBUG
                    print("Failed to post error:", error.localizedDescription)
                #endif
            }
        }
    }
}
