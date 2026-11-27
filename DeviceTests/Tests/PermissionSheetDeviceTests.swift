import Foundation
import HealthKit
import Testing
import UIKit
@testable import Sahha

/// Two permission requests back to back, through the SDK's real permissions service and
/// HealthKit's real sheet: the second must show its sheet and complete.
///
/// Why: on iOS 27 HealthKit calls a request's completion while its sheet is still
/// dismissing. Before the fix, the SDK released its request queue right then, the second
/// request was presented on the dismissing sheet, UIKit refused it ("whose view is not in
/// the window hierarchy"), and the request blocked for the 120s timeout and failed. A host
/// app calling enableSensors twice in a row for new sensors hit this.
///
/// Interactive and once per install: it asks for weight, then height, which must never
/// have been asked for. Answer both sheets on the device. To run it again, delete the host
/// app (on a simulator: `xcrun simctl uninstall <id> ai.sahha.sdk.devicetests`).
///
///     TEST_RUNNER_SAHHA_PERMISSION_SHEETS=1 DeviceTests/run.sh <udid> PermissionSheetDeviceTests
///
/// It runs on a simulator too, with xcodebuild and a simulator id (see README.md).
@Suite(
    "Back-to-back permission sheets",
    .serialized,
    .enabled(if: DeviceTestEnv.string("SAHHA_PERMISSION_SHEETS") == "1", "Pass TEST_RUNNER_SAHHA_PERMISSION_SHEETS=1 to run, then answer two Health sheets")
)
struct PermissionSheetDeviceTests {
    @Test("A second request made as the first sheet closes still shows its sheet and completes", .timeLimit(.minutes(10)))
    func backToBackRequestsBothPresent() async throws {
        let store = HKHealthStore()
        let service = HealthKitPermissionsService(healthStore: store)

        let firstStatus = try await service.getPermissionsStatus(for: [.weight])
        let secondStatus = try await service.getPermissionsStatus(for: [.height])
        try #require(
            firstStatus == .shouldRequest && secondStatus == .shouldRequest,
            "Weight or height was already asked for in this install. Delete the host app and run again."
        )

        let recorder = await SheetRecorder()
        await recorder.start()

        let started = Date()
        await recorder.mark("first request (weight)")
        try await service.requestPermissions(for: [.weight])
        let firstSeconds = Date().timeIntervalSince(started)
        await recorder.mark("first returned")
        let sheetsBeforeSecond = await recorder.sheetCount
        let settledOnReturn = await PermissionSheetSettler.isSettled(PermissionSheetSettler.currentChains())

        let secondStarted = Date()
        var secondError: String?
        do {
            try await service.requestPermissions(for: [.height])
        } catch {
            secondError = "\(error)"
        }
        let secondSeconds = Date().timeIntervalSince(secondStarted)
        await recorder.mark("second returned")
        let timeline = await recorder.stop()
        let sheets = await recorder.sheetCount
        let windows = await PermissionSheetSettler.currentChains().count
        let heightStatus = try await service.getPermissionsStatus(for: [.height])

        DeviceTestReport.record("permission-back-to-back", [
            "firstSeconds": DeviceTestReport.seconds(firstSeconds),
            "secondSeconds": DeviceTestReport.seconds(secondSeconds),
            "secondError": secondError ?? "none",
            "healthSheetsShown": sheets,
            "settledWhenFirstReturned": settledOnReturn,
            "heightStatusAfter": heightStatus == .unnecessary ? "unnecessary" : "\(heightStatus.rawValue)",
            "timeline": timeline,
        ])

        // The settler must be reading this app's windows, or it would wait for nothing.
        #expect(windows > 0, "PermissionSheetSettler found no windows in a running app")
        #expect(sheetsBeforeSecond == 1)
        #expect(settledOnReturn, "The first request returned while its sheet was still on screen")
        #expect(secondError == nil)
        #expect(sheets == 2, "The second request's sheet never appeared")
        #expect(heightStatus == .unnecessary, "Height is still undetermined after the second request")
    }
}

/// Samples every window's presentation chain on the main thread: counts the Health
/// sheets that appear, and keeps a timeline of the changes for the report.
@MainActor
final class SheetRecorder {
    /// Sheets that appeared on a screen that had none. Counted by appearance, not by
    /// identity: the second sheet can reuse the first one's freed address.
    private(set) var sheetCount = 0
    private var sheetWasOnScreen = false
    private var lines: [String] = []
    private var last = ""
    private var started = Date()
    private var task: Task<Void, Never>?

    func start() {
        started = Date()
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.sample()
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }

    func mark(_ label: String) {
        sample()
        append("-- \(label)")
    }

    func stop() -> [String] {
        task?.cancel()
        sample()
        return lines
    }

    private func append(_ text: String) {
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        lines.append("\(ms)ms \(text)")
        print("[SheetRecorder] \(ms)ms \(text)")
    }

    private func sample() {
        var chains: [String] = []
        var sheetOnScreen = false
        for scene in UIApplication.shared.connectedScenes {
            guard let scene = scene as? UIWindowScene else { continue }
            for window in scene.windows {
                var chain: [String] = []
                var controller = window.rootViewController
                while let current = controller {
                    var name = String(String(describing: type(of: current)).prefix { $0 != "<" })
                    if PermissionSheetSettler.isHealthPermissionSheet(current) {
                        name = "HealthSheet"
                        sheetOnScreen = true
                    }
                    if current.isBeingPresented { name += "(presenting)" }
                    if current.isBeingDismissed { name += "(dismissing)" }
                    chain.append(name)
                    controller = current.presentedViewController
                }
                // Only chains with something presented are worth a line.
                if chain.count > 1 { chains.append(chain.joined(separator: " > ")) }
            }
        }
        if sheetOnScreen && !sheetWasOnScreen { sheetCount += 1 }
        sheetWasOnScreen = sheetOnScreen
        let description = chains.isEmpty ? "nothing presented" : chains.joined(separator: " | ")
        if description != last {
            last = description
            append(description)
        }
    }
}
