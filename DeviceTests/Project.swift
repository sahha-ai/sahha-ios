import ProjectDescription

// Real-device regression suite for the Sahha SDK. `tuist generate` turns this into
// SahhaDeviceTests.xcodeproj (ignored by git); see README.md.
//
// The host app exists for its entitlements: package test bundles cannot carry
// HealthKit, so the tests are injected into this app's process instead. Only the test
// bundle links Sahha, so there is one copy of the SDK in the process.
//
// SahhaWakeCheck is a separate app that integrates the SDK the way a customer's app does,
// for the background checks in MANUAL_CHECKLIST.md that XCTest can't drive. It has its own
// bundle id, so its keychain, Health permissions and profile are separate from the tests'.

let teamId = Environment.developmentTeam.getString(default: "DFT926V374")

/// Shared by the wake-check app's Info.plist and the identifier it registers with the SDK.
let wakeCheckRefreshTask = "ai.sahha.sdk.wakecheck.refresh"

let project = Project(
    name: "SahhaDeviceTests",
    packages: [.local(path: "..")],
    settings: .settings(base: [
        "DEVELOPMENT_TEAM": .string(teamId),
        "CODE_SIGN_STYLE": "Automatic",
        "SWIFT_VERSION": "5.0",
    ]),
    targets: [
        .target(
            name: "SahhaDeviceHost",
            destinations: [.iPhone],
            product: .app,
            bundleId: "ai.sahha.sdk.devicetests",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "NSHealthShareUsageDescription": "Reads the test samples the Sahha SDK device tests write.",
                "NSHealthUpdateUsageDescription": "Writes, then deletes, test samples for the Sahha SDK device tests.",
            ]),
            sources: ["Host/**"],
            entitlements: .dictionary([
                "com.apple.developer.healthkit": true,
                "com.apple.developer.healthkit.access": [],
                // Lets the SDK enable background delivery, as a host app does, so
                // `enableBackgroundDelivery` is exercised rather than failing for want
                // of the entitlement.
                "com.apple.developer.healthkit.background-delivery": true,
            ])
        ),
        .target(
            name: "SahhaDeviceTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "ai.sahha.sdk.devicetests.tests",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "SahhaDeviceHost"),
                .package(product: "Sahha"),
            ]
        ),
        .target(
            name: "SahhaWakeCheck",
            destinations: [.iPhone],
            product: .app,
            bundleId: "ai.sahha.sdk.wakecheck",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Wake Check",
                "UILaunchScreen": [:],
                "NSHealthShareUsageDescription": "Reads steps and heart rate so the Sahha SDK wake check can upload them.",
                "NSHealthUpdateUsageDescription": "The Sahha SDK wake check does not write health data.",
                // The SDK's background refresh: the identifier must be permitted here, and
                // BGAppRefreshTask needs the fetch mode.
                "BGTaskSchedulerPermittedIdentifiers": [.string(wakeCheckRefreshTask)],
                "UIBackgroundModes": ["fetch"],
                "SahhaWakeCheckRefreshTask": .string(wakeCheckRefreshTask),
            ]),
            sources: ["WakeCheck/**"],
            entitlements: .dictionary([
                "com.apple.developer.healthkit": true,
                "com.apple.developer.healthkit.access": [],
                "com.apple.developer.healthkit.background-delivery": true,
            ]),
            dependencies: [
                .package(product: "Sahha"),
            ]
        ),
    ],
    schemes: [
        // Declared rather than left to Tuist's generated default, to pin one thing: the
        // suites run one at a time. Every suite shares this app's HealthKit store,
        // keychain and live test profile, and `.serialized` only orders tests within a
        // suite, so suites running side by side would delete each other's samples
        // (first-sync clean-up removes every step this app wrote) and skew the timings.
        .scheme(
            name: "SahhaDeviceTests",
            shared: true,
            buildAction: .buildAction(targets: ["SahhaDeviceTests"]),
            testAction: .targets(
                [.testableTarget(target: "SahhaDeviceTests", parallelization: .disabled)],
                configuration: .debug
            )
        ),
        .scheme(
            name: "SahhaWakeCheck",
            shared: true,
            buildAction: .buildAction(targets: ["SahhaWakeCheck"]),
            runAction: .runAction(configuration: .debug, executable: "SahhaWakeCheck")
        ),
    ]
)
