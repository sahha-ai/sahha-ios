/// Biomarker categories available from the Sahha API.
/// Matches the categories documented at https://docs.sahha.ai/docs/products/biomarkers
public enum SahhaBiomarkerCategory: String, CaseIterable, Sendable {
    case activity
    case body
    case engagement
    case nutrition
    case sleep
    case vitals
}
