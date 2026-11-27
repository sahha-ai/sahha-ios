/// `CaseIterable` so `baseURL` can be proven total in tests — every environment
/// is asserted to produce a well-formed absolute URL, including ones added later.
public enum SahhaEnvironment: String, CaseIterable, Sendable {
    case development
    case sandbox
    case production
}
