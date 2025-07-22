// TEMPORARY: Synchronous access to profileToken for legacy API needs.
// This will be removed when Sahha migrates to full async/await.
// Used by Sahha.profileToken and Sahha.isAuthenticated.

final class AuthSnapshot: @unchecked Sendable {
    var profileToken: String?
    var isAuthenticated: Bool {
        profileToken != nil && !profileToken!.isEmpty
    }
}
