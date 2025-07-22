import Foundation

// MARK: Sahha Validator

enum SahhaValidator {
    private typealias AsyncValidationCheck = () async -> ValidationError?

    private static func validate(_ checks: [AsyncValidationCheck]) async throws {
        var errors: [ValidationError] = []
        for check in checks {
            if let error = await check() {
                errors.append(error)
            }
        }
        if !errors.isEmpty {
            throw ValidationError.validationFailed(errors)
        }
    }

    private static func checkAuthentication() async -> ValidationError? {
        await MainActor.run {
            !Sahha.isAuthenticated ? .authenticationRequired : nil
        }
    }

    private static func checkNotEmpty(_ str: String, field: String) -> ValidationError? {
        str.isEmpty ? .emptyString(field: field) : nil
    }

    private static func checkNotEmptyCollection<T>(_ collection: T, name: String) -> ValidationError? where T: Collection {
        collection.isEmpty ? .emptyCollection(collection: name) : nil
    }

    private static func checkDateRange(start: Date, end: Date) -> ValidationError? {
        start > end ? .invalidDateRange : nil
    }
}

// MARK: Validation Helpers

extension SahhaValidator {
    static func validateAuthenticate(appId: String, appSecret: String, externalId: String) async throws {
        try await validate([
            { checkNotEmpty(appId, field: "appId") },
            { checkNotEmpty(appSecret, field: "appSecret") },
            { checkNotEmpty(externalId, field: "externalId") },
        ])
    }

    static func validateAuthenticate(profileToken: String, refreshToken: String) async throws {
        try await validate([
            { checkNotEmpty(profileToken, field: "profileToken") },
            { checkNotEmpty(refreshToken, field: "refreshToken") },
        ])
    }
    
    static func validateGetDemographic() async throws {
        try await validate([
            { await checkAuthentication() }
        ])
    }
    
    static func validatePostDemographic() async throws {
        try await validate([
            { await checkAuthentication() }
        ])
    }

    static func validateEnableSensors(sensors: Set<SahhaSensor>) async throws {
        try await validate([
            { await checkAuthentication() },
            { checkNotEmptyCollection(sensors, name: "sensors") },
        ])
    }

    static func validateGetSensorStatus(sensors: Set<SahhaSensor>) async throws {
        try await validate([
            { checkNotEmptyCollection(sensors, name: "sensors") }
        ])
    }

    static func validateGetStats(startDate: Date, endDate: Date) async throws {
        try await validate([
            { checkDateRange(start: startDate, end: endDate) }
        ])
    }

    static func validateGetSamples(startDate: Date, endDate: Date) async throws {
        try await validate([
            { checkDateRange(start: startDate, end: endDate) }
        ])
    }

    static func validateGetScores(types: Set<SahhaScoreType>, startDate: Date, endDate: Date) async throws {
        try await validate([
            { await checkAuthentication() },
            { checkNotEmptyCollection(types, name: "types") },
            { checkDateRange(start: startDate, end: endDate) },
        ])
    }

    static func validateGetBiomarkers(
        categories: Set<SahhaBiomarkerCategory>,
        types: Set<SahhaBiomarkerType>,
        startDate: Date,
        endDate: Date
    ) async throws {
        try await validate([
            { await checkAuthentication() },
            { checkNotEmptyCollection(categories, name: "categories") },
            { checkNotEmptyCollection(types, name: "types") },
            { checkDateRange(start: startDate, end: endDate) },
        ])
    }
}

// MARK: Validation Error

private enum ValidationError: LocalizedError {
    case authenticationRequired
    case emptyString(field: String)
    case emptyCollection(collection: String)
    case invalidDateRange
    case validationFailed([ValidationError])

    var errorDescription: String? {
        switch self {
        case .emptyString(let field):
            return "The \(field) field can not be empty."
        case .emptyCollection(let collection):
            return "The \(collection) collection can not be empty."
        case .invalidDateRange:
            return "Start date must be before end date."
        case .authenticationRequired:
            return "Authentication required. Please call `Sahha.authenticate(...)` before using this function."
        case .validationFailed(let errors):
            return errors.map { $0.localizedDescription }.joined(separator: "\n")
        }
    }
}
