public final class Sahha {
    
    public static func configure(_ settings: SahhaSettings, callback: (@Sendable () -> Void)? = nil) {
        Task {
            await ConfigurationStore.shared.set(settings)
            await RefreshTokenManager.shared.scheduleRefresh()
            callback?()
        }
    }
}
