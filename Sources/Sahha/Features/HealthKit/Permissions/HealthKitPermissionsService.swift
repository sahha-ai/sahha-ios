import HealthKit

final class HealthKitPermissionsService: HealthKitPermissionsServiceProtocol {
    /// How long an authorization request may remain unresolved before the SDK stops
    /// waiting. Generous, because the await legitimately includes the time a user
    /// spends reading the permission sheet.
    static let defaultRequestTimeout: TimeInterval = 120

    private let healthStore: HKHealthStore
    private let requestTimeout: TimeInterval
    /// Serializes authorization requests. Concurrent `requestAuthorization` calls on
    /// the same `HKHealthStore` (e.g. `enableSensors` invoked again while the
    /// permission sheet is up) can leave one continuation suspended forever; queueing
    /// the second request until the first resolves avoids that.
    private let requestSerializer = AsyncSemaphore(value: 1)
    /// Holds each request until the screen can take its sheet. See `PermissionSheetSettling`.
    private let sheetSettler: PermissionSheetSettling

    init(
        healthStore: HKHealthStore = .init(),
        requestTimeout: TimeInterval = HealthKitPermissionsService.defaultRequestTimeout,
        sheetSettler: PermissionSheetSettling = PermissionSheetSettler()
    ) {
        self.healthStore = healthStore
        self.requestTimeout = requestTimeout
        self.sheetSettler = sheetSettler
    }

    func requestPermissions(for sensors: Set<SahhaSensor>) async throws {
        guard !sensors.isEmpty else {
            throw SahhaError(message: "Sensor set cannot be empty.")
        }

        let permissions = Set(sensors.flatMap(\.hkPermissions))

        // Some sensors (e.g. .device_lock) have no HealthKit backing, so a set
        // composed entirely of them has nothing to authorize — succeed as a no-op.
        guard !permissions.isEmpty else { return }

        await requestSerializer.wait()

        // A sheet still on screen (one the host app requested, say) or a presentation
        // still animating would swallow this request's sheet, leaving it to time out.
        await sheetSettler.waitUntilSettled()

        let outcome: Result<Void, Error>
        do {
            let healthStore = self.healthStore
            try await withAbandoningTimeout(
                seconds: requestTimeout,
                operationName: "HealthKit authorization request"
            ) {
                try await healthStore.requestAuthorization(toShare: [], read: permissions)
            }
            outcome = .success(())
        } catch {
            outcome = .failure(error)
        }

        // HealthKit calls back while the sheet is still animating away. Hold the
        // serializer, and the caller, until it has gone, so the next request (queued
        // here, or the host app's own) and any UI the host presents on return have
        // somewhere to present. Without this, a second enableSensors right after the
        // first showed no sheet on iOS 27 and failed at the request timeout.
        await sheetSettler.waitUntilSettled()
        await requestSerializer.signal()
        try outcome.get()
    }
    
    func getPermissionsStatus(for sensors: Set<SahhaSensor>) async throws -> HKAuthorizationRequestStatus {
        guard !sensors.isEmpty else {
            throw SahhaError(message: "Sensor set cannot be empty.")
        }
        
        let permissions = Set(sensors.flatMap(\.hkPermissions))

        // No HealthKit-backed types means no authorization request is needed.
        guard !permissions.isEmpty else { return .unnecessary }

        return try await healthStore.statusForAuthorizationRequest(toShare: [], read: permissions)
    }
    
    func hasPermissions(for sensor: SahhaSensor) async throws -> Bool {
        let permissions = sensor.hkPermissions
        
        if permissions.isEmpty { return false }
        
        let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: permissions)
        
        return status == .unnecessary
    }
}
