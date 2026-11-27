import SwiftUI
import UIKit
import Sahha

struct WakeCheckView: View {
    @State private var lines: [String] = []
    @State private var signedIn = Sahha.isAuthenticated
    @State private var sensorStatus = "…"
    @State private var confirmingQuit = false

    var body: some View {
        NavigationStack {
            List {
                Section("Session") {
                    row("Environment", WakeCheckSession.environmentName)
                    row("Profile", WakeCheckSession.externalId)
                    row("Signed in", signedIn ? "yes" : "no")
                    row("Steps and heart rate", sensorStatus)
                }
                Section {
                    Button("Enable steps and heart rate", action: enableSensors)
                        .disabled(!signedIn)
                    Button("Quit, as iOS would") { confirmingQuit = true }
                    Button("Clear the log", role: .destructive) {
                        WakeLog.shared.clear()
                        refreshLog()
                    }
                    Button("Sign out", role: .destructive, action: signOut)
                        .disabled(!signedIn)
                } footer: {
                    Text("Quit ends the app without the app switcher, so iOS can still launch it in the background. Swiping it away in the app switcher stops background launches until you open it again.")
                }
                Section("Latest events, newest first") {
                    ForEach(Array(lines.enumerated().reversed()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Wake Check")
            .confirmationDialog("Quit the app?", isPresented: $confirmingQuit, titleVisibility: .visible) {
                Button("Quit", role: .destructive) {
                    WakeLog.shared.record("quitting, as iOS would end the app")
                    WakeLog.shared.flushBeforeExit()
                    exit(0)
                }
            } message: {
                Text("Then add data in the Health app, lock the phone, and don't reopen this app.")
            }
            .task {
                refreshStatus()
                while !Task.isCancelled {
                    refreshLog()
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                refreshStatus()
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func refreshLog() {
        lines = WakeLog.shared.tail(120)
        signedIn = Sahha.isAuthenticated
    }

    private func refreshStatus() {
        signedIn = Sahha.isAuthenticated
        guard signedIn else { sensorStatus = "not signed in"; return }
        Sahha.getSensorStatus(WakeCheckSession.sensors) { error, status in
            DispatchQueue.main.async { sensorStatus = error.map { "\(status) (\($0))" } ?? "\(status)" }
        }
    }

    private func enableSensors() {
        Sahha.enableSensors(WakeCheckSession.sensors) { error, status in
            WakeLog.shared.record("enable sensors: \(status)\(error.map { ", error: \($0)" } ?? "")")
            DispatchQueue.main.async { refreshStatus() }
        }
    }

    private func signOut() {
        Sahha.deauthenticate { error, success in
            if success { WakeCheckSession.signedOut() }
            WakeLog.shared.record(success ? "signed out" : "sign-out failed: \(error ?? "no error given")")
            DispatchQueue.main.async { refreshStatus() }
        }
    }
}
