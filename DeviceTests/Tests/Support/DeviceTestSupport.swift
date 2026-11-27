import Foundation
import HealthKit
import UIKit
@testable import Sahha

// MARK: - Run-time settings

/// Settings passed at run time. xcodebuild forwards every `TEST_RUNNER_<NAME>` variable
/// to the test process as `<NAME>`, so `TEST_RUNNER_SAHHA_SEED_DAYS=730` arrives here as
/// `SAHHA_SEED_DAYS`. Nothing secret is ever committed.
enum DeviceTestEnv {
    static func string(_ key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else { return nil }
        return value
    }

    static func int(_ key: String, default fallback: Int) -> Int {
        string(key).flatMap(Int.init) ?? fallback
    }

    /// Days of step history to seed, all older than the SDK's 30-day window.
    static var seedDays: Int { int("SAHHA_SEED_DAYS", default: 365) }

    /// Step samples per seeded day. 288 is one every five minutes.
    static var seedSamplesPerDay: Int { int("SAHHA_SEED_PER_DAY", default: 288) }

    /// Leave the seeded samples in HealthKit after the run, to skip reseeding next time.
    static var keepSeeded: Bool { string("SAHHA_KEEP_SEEDED") == "1" }

    static var appId: String? { string("SAHHA_APP_ID") }
    static var appSecret: String? { string("SAHHA_APP_SECRET") }
    static var hasAppCredentials: Bool { appId != nil && appSecret != nil }

    /// The API the live tests talk to. Production is refused: these tests register a
    /// profile and rotate its tokens.
    static var apiEnvironment: SahhaEnvironment {
        let environment = string("SAHHA_ENVIRONMENT").flatMap(SahhaEnvironment.init(rawValue:)) ?? .sandbox
        return environment == .production ? .sandbox : environment
    }
}

// MARK: - HealthKit

enum DeviceTestError: Error, CustomStringConvertible {
    case healthWriteNotAllowed

    var description: String {
        switch self {
        case .healthWriteNotAllowed:
            return "Step count writing is off for Sahha Device Tests. Turn it on in Settings > Health > Data Access & Devices, then run again."
        }
    }
}

/// The real Health store, plus the seeding and clean-up these tests need. Every sample
/// it writes comes from this app's own source, which is how clean-up finds them: no
/// other app's data is ever touched.
final class DeviceHealthStore: @unchecked Sendable {
    static let shared = DeviceHealthStore()

    let store = HKHealthStore()
    let steps = HKQuantityType.quantityType(forIdentifier: .stepCount)!

    /// Shows the Health permission sheet on the first run only. Read access cannot be
    /// checked (HealthKit hides it), so only write access is verified.
    func authorize() async throws {
        try await store.requestAuthorization(toShare: [steps], read: [steps])
        guard store.authorizationStatus(for: steps) == .sharingAuthorized else {
            throw DeviceTestError.healthWriteNotAllowed
        }
    }

    /// Only samples this app wrote: the filter every count and delete goes through.
    private var ownSamples: NSPredicate { HKQuery.predicateForObjects(from: HKSource.default()) }

    /// How many step samples this app has in HealthKit. Every seeded sample is 12 steps,
    /// so the sum gives the count without fetching millions of objects.
    func seededSampleCount() async throws -> Int {
        try await run { finish in
            HKStatisticsQuery(quantityType: self.steps, quantitySamplePredicate: self.ownSamples, options: .cumulativeSum) { _, statistics, error in
                if let error = error as? HKError, error.code == .errorNoData {
                    finish(.success(0))
                } else if let error {
                    finish(.failure(error))
                } else {
                    let total = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    finish(.success(Int((total / 12).rounded())))
                }
            }
        }
    }

    /// The start of the oldest step sample this app has written, or nil when it has none.
    func oldestSeededSampleStart() async throws -> Date? {
        try await run { finish in
            HKSampleQuery(
                sampleType: self.steps,
                predicate: self.ownSamples,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error as? HKError, error.code == .errorNoData {
                    finish(.success(nil))
                } else if let error {
                    finish(.failure(error))
                } else {
                    finish(.success(samples?.first?.startDate))
                }
            }
        }
    }

    /// Runs the query `makeQuery` builds, which hands its result to `finish`. Cancelling
    /// the task stops the query and throws CancellationError. Without that, a `.timeLimit`
    /// cancels the test but leaves it waiting on HealthKit forever, because
    /// `HKHealthStore.stop` never calls the query's handler. That wait is what happens
    /// behind a long delete still running inside HealthKit.
    private func run<T>(
        _ makeQuery: (_ finish: @escaping @Sendable (Result<T, Error>) -> Void) -> HKQuery
    ) async throws -> T {
        let pending = PendingQuery<T>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let query = makeQuery { result in pending.finish(result) }
                if pending.start(query, continuation) {
                    store.execute(query)
                }
            }
        } onCancel: {
            if let query = pending.cancel() {
                store.stop(query)
            }
        }
    }

    /// Deletes every step sample this app has written, a month at a time from its oldest
    /// sample onward, so no seed length can leave samples behind. A single delete of 1.75M
    /// samples ran for over two hours on an iPhone 14 and blocked every other HealthKit
    /// query from the app; month-sized deletes make progress, and a stopped run leaves a
    /// smaller remainder for the next one. Returns how many went.
    @discardableResult
    func deleteSeeded(progress: ((_ deletedSoFar: Int) -> Void)? = nil) async throws -> Int {
        guard let oldest = try await oldestSeededSampleStart() else { return 0 }
        let calendar = Calendar.current
        let now = Date().addingTimeInterval(86_400)
        // A day early, so the first chunk's range certainly covers the oldest sample.
        var chunkStart = oldest.addingTimeInterval(-86_400)
        var deleted = 0
        while chunkStart < now {
            let chunkEnd = min(calendar.date(byAdding: .month, value: 1, to: chunkStart)!, now)
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                ownSamples,
                HKQuery.predicateForSamples(withStart: chunkStart, end: chunkEnd),
            ])
            deleted += try await deleteSamples(matching: predicate)
            progress?(deleted)
            chunkStart = chunkEnd
        }
        return deleted
    }

    private func deleteSamples(matching predicate: NSPredicate) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            store.deleteObjects(of: steps, predicate: predicate) { _, count, error in
                if let error = error as? HKError, error.code == .errorNoData {
                    continuation.resume(returning: 0)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: count)
                }
            }
        }
    }

    /// Writes `days` of step history ending at `end`, oldest first, the order a real
    /// history accumulates in. Returns the number of samples saved.
    func seedStepHistory(days: Int, samplesPerDay: Int, endingAt end: Date) async throws -> Int {
        let spacing = 86_400.0 / Double(samplesPerDay)
        let start = end.addingTimeInterval(-Double(days) * 86_400)
        let total = days * samplesPerDay
        let batchSize = 5_000
        var batch: [HKObject] = []
        batch.reserveCapacity(batchSize)
        var saved = 0

        for index in 0..<total {
            let sampleStart = start.addingTimeInterval(Double(index) * spacing)
            batch.append(HKQuantitySample(
                type: steps,
                quantity: HKQuantity(unit: .count(), doubleValue: 12),
                start: sampleStart,
                end: sampleStart.addingTimeInterval(min(60, spacing)),
                metadata: ["SahhaDeviceTestSeed": true]
            ))
            if batch.count == batchSize {
                try await store.save(batch)
                saved += batch.count
                batch.removeAll(keepingCapacity: true)
            }
        }
        if !batch.isEmpty {
            try await store.save(batch)
            saved += batch.count
        }
        return saved
    }
}

/// One query's continuation, resumed exactly once by whichever comes first: the query's
/// result or the task's cancellation.
private final class PendingQuery<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var query: HKQuery?
    private var cancelled = false

    /// Whether to execute the query. False when the task was already cancelled, in which
    /// case the continuation has been resumed with CancellationError.
    func start(_ query: HKQuery, _ continuation: CheckedContinuation<T, Error>) -> Bool {
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return false
        }
        self.query = query
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func finish(_ result: Result<T, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        query = nil
        lock.unlock()
        continuation?.resume(with: result)
    }

    /// Resumes with CancellationError and returns the query to stop, if one is running.
    func cancel() -> HKQuery? {
        lock.lock()
        cancelled = true
        let continuation = self.continuation
        let query = self.query
        self.continuation = nil
        self.query = nil
        lock.unlock()
        continuation?.resume(throwing: CancellationError())
        return query
    }
}

// MARK: - Results

/// Writes each test's measurements to the console and to the host app's
/// Documents/device-test-results/<run id>/ folder, which DeviceTests/run.sh copies back.
///
/// The folder persists on the phone between runs, so each run writes to its own
/// subfolder (named by SAHHA_RUN_ID, which run.sh sets) and clears every other run's on
/// its first write. Otherwise a run that records nothing, or fails early, would collect
/// the reports an earlier run left behind.
enum DeviceTestReport {
    static func record(_ name: String, _ values: [String: Any]) {
        var report = values
        report["recordedAt"] = ISO8601DateFormatter().string(from: Date())
        report["device"] = deviceModel()
        report["system"] = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        report["sdkVersion"] = SDK.version
        report["runId"] = runId

        let data = (try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        try? data.write(to: runFolder.appendingPathComponent("\(name).json"))
        print("[DeviceTestReport] \(name)\n\(String(decoding: data, as: UTF8.self))")
    }

    /// Unique per process when run from Xcode without run.sh, so those runs don't mix either.
    private static let runId: String = DeviceTestEnv.string("SAHHA_RUN_ID")
        ?? "manual-\(Int(Date().timeIntervalSince1970))"

    /// Created, and every other run's reports removed, on the first write of the process.
    /// A static let initialises once, thread-safely.
    private static let runFolder: URL = {
        let fileManager = FileManager.default
        let root = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("device-test-results", isDirectory: true)
        let folder = root.appendingPathComponent(runId, isDirectory: true)
        for entry in (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        where entry.lastPathComponent != runId {
            try? fileManager.removeItem(at: entry)
        }
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }()

    private static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    /// Seconds to the millisecond, as a decimal so the JSON reads 0.008, not 0.0080000000000000002.
    static func seconds(_ interval: TimeInterval) -> NSDecimalNumber {
        NSDecimalNumber(string: String(format: "%.3f", interval))
    }
}

// MARK: - Doubles

/// Discards errors: these tests assert on outcomes, not on what the SDK would post.
struct SilentErrorLogger: ErrorLoggerProtocol {
    func postError(_ error: Error, file: StaticString, function: StaticString, line: UInt) {}
}

/// A token store that lives only for the test, so the live-API test never touches the
/// keychain session.
actor InMemoryTokenStore: TokenStoreProtocol {
    private var current: TokenResponse?
    private(set) var saveCount = 0

    init(_ token: TokenResponse?) { current = token }

    func saveToken(_ token: TokenResponse) throws {
        saveCount += 1
        current = token
    }
    func token() -> TokenResponse? { current }
    func profileToken() -> String? { current?.profileToken }
    func refreshToken() -> String? { current?.refreshToken }
    func clearToken() { current = nil }
    func dispose() async { current = nil }
}

/// UserDefaults stand-in, so the keychain test leaves no persisted profile id behind.
final class InMemoryDefaults: UserDefaultsStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any] = [:]

    func set(_ value: Any?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }
    func get(forKey key: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }
    func removeObject(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        values[key] = nil
    }
    func allKeys() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(values.keys)
    }
}
