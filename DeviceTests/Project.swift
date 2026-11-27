import ProjectDescription

// Real-device regression suite for the Sahha SDK. `tuist generate` turns this into
// SahhaDeviceTests.xcodeproj (ignored by git); see README.md.
//
// The host app exists for its entitlements: package test bundles cannot carry
// HealthKit, so the tests are injected into this app's process instead. Only the test
// bundle links Sahha, so there is one copy of the SDK in the process.

let teamId = Environment.developmentTeam.getString(default: "DFT926V374")

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
    ]
)
