import SwiftUI

/// Hosts the device tests. Nothing runs here: the test bundle is injected into this
/// process so it gets the app's HealthKit entitlement, keychain and network.
@main
struct SahhaDeviceHostApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 8) {
                Text("Sahha SDK device tests").font(.headline)
                Text("Run the suite from Xcode or xcodebuild.").font(.footnote)
            }
            .padding()
        }
    }
}
