/// Launch-gate classification of the persisted session (PRD #76 D10), replacing
/// the boolean `hasValidProfileToken()` gate at configure time. The two
/// deferrable verdicts drive the event-driven bring-up retry; the other two are
/// final for the life of the configure.
enum LaunchAuthVerdict: Sendable, Equatable {
    /// A usable profile token exists (refreshed if it had to be): start
    /// authenticated services now.
    case valid
    /// The store read cleanly and holds no session: nothing to bring up, and
    /// nothing a retry could change.
    case unauthenticated
    /// The token refresh failed recoverably (offline, timeout, 5xx,
    /// uncorroborated 4xx). The tokens were kept, so a later attempt can
    /// succeed: defer bring-up and retry.
    case transientRefreshFailure
    /// The corroborated dead-session verdict: the tokens are already cleared,
    /// and no retry can succeed without new credentials.
    case terminalSessionExpiry
    /// The keychain read itself failed (e.g. a background launch before first
    /// unlock): the session state is unknown — indistinguishable from signed
    /// out until a store reload succeeds. Defer and retry, primarily on the
    /// protected-data-available event.
    case tokenStoreUnreadable
}
