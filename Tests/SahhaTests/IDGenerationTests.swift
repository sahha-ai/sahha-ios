import Testing
import Foundation
@testable import Sahha

// MARK: - Mocks

final class MockProfileIdProvider: ProfileIdProviderProtocol, @unchecked Sendable {
    var _profileId: String?
    func profileId() -> String? { _profileId }
}

// MARK: - UUIDFactory Tests

@Test("UUIDFactory: Same inputs produce same UUID5")
func testUUID5Determinism() {
    let components: [Any] = ["profile123", "sleep", "sleep_stage_light", "HealthKit", "2024-01-15 10:30:00"]
    let id1 = UUIDFactory.v5(from: components)
    let id2 = UUIDFactory.v5(from: components)
    #expect(id1 == id2)
}

@Test("UUIDFactory: Different inputs produce different UUID5")
func testUUID5Uniqueness() {
    let id1 = UUIDFactory.v5(from: ["a", "b", "c"] as [Any])
    let id2 = UUIDFactory.v5(from: ["a", "b", "d"] as [Any])
    #expect(id1 != id2)
}

@Test("UUIDFactory: UUID5 has correct version and variant bits")
func testUUID5VersionAndVariant() {
    let uuid = UUIDFactory.v5(from: ["test"] as [Any])
    let bytes = uuid.uuid
    #expect((bytes.6 & 0xF0) == 0x50) // Version 5
    #expect((bytes.8 & 0xC0) == 0x80) // RFC 4122 variant
}

@Test("UUIDFactory: UUID5 output matches Go implementation for known input")
func testUUID5CrossPlatformMatch() {
    // Go: uuid.NewSHA1(uuid.NameSpaceDNS, []byte("test"))
    // UUID5("test") with DNS namespace = 4be0643f-1d98-573b-97cd-ca98a65347dd
    let uuid = UUIDFactory.v5(namespace: UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!, name: "test")
    #expect(uuid.uuidString == "4BE0643F-1D98-573B-97CD-CA98A65347DD")
}

// MARK: - JWT ProfileId Extraction Tests

private func createTestJWT(payload: [String: Any]) -> String {
    let header = #"{"alg":"HS256","typ":"JWT"}"#
    let headerEncoded = Data(header.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")

    let payloadData = try! JSONSerialization.data(withJSONObject: payload)
    let payloadEncoded = payloadData.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")

    return "\(headerEncoded).\(payloadEncoded).fake-signature"
}

@Test("JWT: Extracts profileId from valid token")
func testJWTProfileIdExtraction() {
    let payload: [String: Any] = [
        "https://api.sahha.ai/claims/profileId": "test-profile-uuid-123",
        "exp": Date().timeIntervalSince1970 + 3600
    ]
    let jwt = createTestJWT(payload: payload)
    let profileId = JWT.profileId(from: jwt)
    #expect(profileId == "test-profile-uuid-123")
}

@Test("JWT: Returns nil when profileId claim is missing")
func testJWTProfileIdMissing() {
    let payload: [String: Any] = [
        "exp": Date().timeIntervalSince1970 + 3600
    ]
    let jwt = createTestJWT(payload: payload)
    let profileId = JWT.profileId(from: jwt)
    #expect(profileId == nil)
}

@Test("JWT: Returns nil for malformed JWT")
func testJWTProfileIdMalformedToken() {
    #expect(JWT.profileId(from: "not.a.valid-jwt") == nil)
    #expect(JWT.profileId(from: "") == nil)
    #expect(JWT.profileId(from: "only-one-part") == nil)
}

// MARK: - Date Formatter Tests

@Test("DateFormatter: uuidDateTime format matches yyyy-MM-dd HH:mm:ss")
func testUUIDDateTimeFormat() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    let components = DateComponents(year: 2024, month: 3, day: 15, hour: 14, minute: 30, second: 45)
    let date = calendar.date(from: components)!
    let formatted = date.uuidDateTime
    #expect(formatted == "2024-03-15 14:30:45")
}

@Test("DateFormatter: uuidDateTime has no T separator or timezone")
func testUUIDDateTimeNoTOrTimezone() {
    let date = Date()
    let formatted = date.uuidDateTime
    #expect(!formatted.contains("T"))
    #expect(!formatted.contains("+"))
    #expect(!formatted.contains("Z"))
    #expect(formatted.count == 19) // yyyy-MM-dd HH:mm:ss
}

// MARK: - DataLog ID Generation Tests

@Test("DataLog: ID includes profileId in generation")
func testDataLogIDWithProfileId() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let log1 = DataLog(
        profileId: "profile-A",
        logType: .sleep,
        dataType: "sleep_stage_light",
        value: 60.0,
        unit: "minutes",
        source: "HealthKit",
        recordingMethod: .automatic,
        deviceType: "iPhone",
        startDate: date,
        endDate: date
    )
    let log2 = DataLog(
        profileId: "profile-B",
        logType: .sleep,
        dataType: "sleep_stage_light",
        value: 60.0,
        unit: "minutes",
        source: "HealthKit",
        recordingMethod: .automatic,
        deviceType: "iPhone",
        startDate: date,
        endDate: date
    )
    #expect(log1.id != log2.id)
}

@Test("DataLog: ID is deterministic for same inputs")
func testDataLogIDDeterminism() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let log1 = DataLog(
        profileId: "profile-123",
        logType: .heart,
        dataType: "heart_rate",
        value: 72.0,
        unit: "bpm",
        source: "HealthKit",
        recordingMethod: .automatic,
        deviceType: "iPhone",
        startDate: date,
        endDate: date
    )
    let log2 = DataLog(
        profileId: "profile-123",
        logType: .heart,
        dataType: "heart_rate",
        value: 72.0,
        unit: "bpm",
        source: "HealthKit",
        recordingMethod: .automatic,
        deviceType: "iPhone",
        startDate: date,
        endDate: date
    )
    #expect(log1.id == log2.id)
}

@Test("DataLog: ID uses only profileId, logType, dataType, source, endDate")
func testDataLogIDComponents() {
    let endDate = Date(timeIntervalSince1970: 1700000000)
    let startDate1 = Date(timeIntervalSince1970: 1699990000)
    let startDate2 = Date(timeIntervalSince1970: 1699980000)

    // Changing value should NOT change ID
    let logA = DataLog(profileId: "p", logType: .heart, dataType: "hr", value: 72.0, unit: "bpm", source: "HK", recordingMethod: .automatic, deviceType: "iPhone", startDate: startDate1, endDate: endDate)
    let logB = DataLog(profileId: "p", logType: .heart, dataType: "hr", value: 99.0, unit: "bpm", source: "HK", recordingMethod: .automatic, deviceType: "iPhone", startDate: startDate1, endDate: endDate)
    #expect(logA.id == logB.id)

    // Changing deviceType should NOT change ID
    let logC = DataLog(profileId: "p", logType: .heart, dataType: "hr", value: 72.0, unit: "bpm", source: "HK", recordingMethod: .automatic, deviceType: "iPad", startDate: startDate1, endDate: endDate)
    #expect(logA.id == logC.id)

    // Changing startDate should NOT change ID
    let logD = DataLog(profileId: "p", logType: .heart, dataType: "hr", value: 72.0, unit: "bpm", source: "HK", recordingMethod: .automatic, deviceType: "iPhone", startDate: startDate2, endDate: endDate)
    #expect(logA.id == logD.id)

    // Changing source SHOULD change ID
    let logE = DataLog(profileId: "p", logType: .heart, dataType: "hr", value: 72.0, unit: "bpm", source: "CoreMotion", recordingMethod: .automatic, deviceType: "iPhone", startDate: startDate1, endDate: endDate)
    #expect(logA.id != logE.id)

    // Changing endDate SHOULD change ID
    let logF = DataLog(profileId: "p", logType: .heart, dataType: "hr", value: 72.0, unit: "bpm", source: "HK", recordingMethod: .automatic, deviceType: "iPhone", startDate: startDate1, endDate: startDate2)
    #expect(logA.id != logF.id)
}

@Test("DataLog: Nil profileId falls back to empty string and produces valid UUID")
func testDataLogIDNilProfileId() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let log = DataLog(
        logType: .activity,
        dataType: "steps",
        value: 100,
        unit: "count",
        source: "CoreMotion",
        recordingMethod: .automatic,
        deviceType: "iPhone",
        startDate: date,
        endDate: date
    )
    #expect(!log.id.isEmpty)
    #expect(UUID(uuidString: log.id) != nil)
}

@Test("DataLog: ID matches manual UUID5 computation")
func testDataLogIDMatchesManualComputation() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let expectedDateStr = date.uuidDateTime
    let components: [Any] = ["profile-test", DataLogType.sleep.stringValue, "sleep_stage_light", "HealthKit", expectedDateStr]
    let expectedId = UUIDFactory.v5(from: components).uuidString

    let log = DataLog(
        profileId: "profile-test",
        logType: .sleep,
        dataType: "sleep_stage_light",
        value: 30.0,
        unit: "minutes",
        source: "HealthKit",
        recordingMethod: .automatic,
        deviceType: "iPhone",
        startDate: date,
        endDate: date
    )
    #expect(log.id == expectedId)
}

// MARK: - Tag ID Generation Tests

@Test("Tag: ID includes profileId in generation")
func testTagIDWithProfileId() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let tag1 = Tag(profileId: "profile-A", type: .event, startDateTime: date, name: "menstrual_flow", category: "reproductive", source: "HealthKit")
    let tag2 = Tag(profileId: "profile-B", type: .event, startDateTime: date, name: "menstrual_flow", category: "reproductive", source: "HealthKit")
    #expect(tag1.id != tag2.id)
}

@Test("Tag: ID is deterministic for same inputs")
func testTagIDDeterminism() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let tag1 = Tag(profileId: "profile-123", type: .event, startDateTime: date, name: "menstrual_flow", category: "reproductive", source: "HealthKit")
    let tag2 = Tag(profileId: "profile-123", type: .event, startDateTime: date, name: "menstrual_flow", category: "reproductive", source: "HealthKit")
    #expect(tag1.id == tag2.id)
}

@Test("Tag: ID uses correct components")
func testTagIDComponents() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let expectedDateStr = date.uuidDateTime
    let components: [Any] = ["profile-test", TagType.event.rawValue, "reproductive", "menstrual_flow", "HealthKit", expectedDateStr]
    let expectedId = UUIDFactory.v5(from: components).uuidString

    let tag = Tag(profileId: "profile-test", type: .event, startDateTime: date, name: "menstrual_flow", category: "reproductive", source: "HealthKit")
    #expect(tag.id == expectedId)
}

@Test("Tag: Nil category uses empty string in ID components")
func testTagIDNilCategory() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let expectedDateStr = date.uuidDateTime
    let components: [Any] = ["profile-test", TagType.event.rawValue, "", "some_tag", "HealthKit", expectedDateStr]
    let expectedId = UUIDFactory.v5(from: components).uuidString

    let tag = Tag(profileId: "profile-test", type: .event, startDateTime: date, name: "some_tag", source: "HealthKit")
    #expect(tag.id == expectedId)
}

@Test("Tag: Nil profileId falls back to empty string")
func testTagIDNilProfileId() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let tag = Tag(type: .event, startDateTime: date, name: "test", source: "HealthKit")
    #expect(!tag.id.isEmpty)
    #expect(UUID(uuidString: tag.id) != nil)
}

// MARK: - DataLog parentId Tests

@Test("DataLog: Parent-child parentId references parent's new-format ID")
func testDataLogParentChildConsistency() {
    let startDate = Date(timeIntervalSince1970: 1700000000)
    let endDate = Date(timeIntervalSince1970: 1700003600)
    let profileId = "test-profile-id"

    let parent = DataLog(
        profileId: profileId,
        logType: .exercise,
        dataType: "exercise_session_running",
        value: 1.0,
        unit: "count",
        source: "HealthKit",
        recordingMethod: .automatic,
        deviceType: "iPhone",
        startDate: startDate,
        endDate: endDate
    )

    let child = DataLog(
        profileId: profileId,
        parentId: parent.id,
        logType: .exercise,
        dataType: "exercise_event_pause",
        value: 1.0,
        unit: "count",
        source: "HealthKit",
        recordingMethod: .automatic,
        deviceType: "iPhone",
        startDate: startDate,
        endDate: endDate
    )

    #expect(child.parentId == parent.id)
    #expect(UUID(uuidString: parent.id) != nil)
    #expect(UUID(uuidString: child.id) != nil)
    #expect(child.id != parent.id)
}

// MARK: - Cross-Platform UUID5 Vector Tests

/// These UUIDs are generated using the Go server logic:
/// uuid.NewSHA1(uuid.NameSpaceDNS, []byte(strings.Join(parts, "")))
/// The existing testUUID5CrossPlatformMatch test proves the core algorithm matches Go.
/// These vectors verify the full DataLog concatenation produces correct UUIDs.

@Test("Cross-platform: DataLog UUID5 vectors match Go server output")
func testCrossPlatformDataLogVectors() {
    let vectors: [(profileId: String, logType: String, dataType: String, source: String, endDate: String, expectedUUID: String)] = [
        ("profile-123", "sleep", "sleep_stage_light", "HealthKit", "2024-01-15 10:30:00", "A47CB00D-186A-56E2-A752-361A4A42A9D1"),
        ("profile-123", "heart", "heart_rate", "HealthKit", "2024-01-15 10:30:00", "2A18BB66-CA2B-5B68-BE07-951A192EAC39"),
        ("profile-123", "activity", "step_count", "HealthKit", "2024-01-15 10:30:00", "55F2DA24-0075-56F8-9AC7-16E3D5040FDC"),
        ("", "sleep", "sleep_stage_light", "HealthKit", "2024-01-15 10:30:00", "9C521BBA-2F69-527F-BE8A-22CA4C4CB1FC"),
        ("profile-123", "exercise", "exercise_session_running", "HealthKit", "2024-06-15 23:59:59", "0B2ED753-5D46-5BC5-8C0D-28D52C4D32CE"),
    ]
    for v in vectors {
        let components: [Any] = [v.profileId, v.logType, v.dataType, v.source, v.endDate]
        let uuid = UUIDFactory.v5(from: components)
        #expect(uuid.uuidString == v.expectedUUID, "Mismatch for \(v.profileId)|\(v.logType)|\(v.dataType)|\(v.source)|\(v.endDate)")
    }
}

// MARK: - DataLogType String Mapping Tests

@Test("DataLogType: stringValue matches Go log type strings")
func testDataLogTypeStringValues() {
    let expected: [(DataLogType, String)] = [
        (.demographic, "demographic"),
        (.sleep, "sleep"),
        (.activity, "activity"),
        (.device, "device"),
        (.heart, "heart"),
        (.blood, "blood"),
        (.oxygen, "oxygen"),
        (.energy, "energy"),
        (.temperature, "temperature"),
        (.body, "body"),
        (.exercise, "exercise"),
        (.nutrition, "nutrition"),
        (.reproductive, "reproductive"),
        (.symptom, "symptom"),
    ]
    for (logType, goString) in expected {
        #expect(logType.stringValue == goString, "DataLogType.\(logType) stringValue is \"\(logType.stringValue)\" but Go expects \"\(goString)\"")
    }
}

// MARK: - Date Formatting Edge Cases

@Test("uuidDateTime: Midnight formats as 00:00:00")
func testMidnightFormat() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    let date = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0))!
    #expect(date.uuidDateTime == "2024-01-01 00:00:00")
}

@Test("uuidDateTime: End of day formats correctly")
func testEndOfDayFormat() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    let date = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
    #expect(date.uuidDateTime == "2024-12-31 23:59:59")
}

@Test("uuidDateTime: Single-digit months and days are zero-padded")
func testZeroPadding() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    let date = calendar.date(from: DateComponents(year: 2024, month: 3, day: 5, hour: 8, minute: 3, second: 7))!
    #expect(date.uuidDateTime == "2024-03-05 08:03:07")
}
