import Foundation

/// The wake check's timeline: one timestamped line per event, in `Documents/wake-check.log`.
///
/// The SDK prints its debug log to stdout, which nobody sees when iOS launches the app in
/// the background. `startCapturingStdout()` routes stdout through a pipe, stamps each line
/// with the time it arrived, and appends it to the file, so the log survives a background
/// launch. Lines still reach the original stdout, so Xcode's console shows them too.
///
/// The SDK's request log prints every header, the app secret and profile token included.
/// Lines are redacted before they are written, so the file holds no credentials.
final class WakeLog: @unchecked Sendable {
    static let shared = WakeLog()

    static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wake-check.log")
    }

    /// Past this, the log moves to `wake-check.previous.log` at the next launch.
    private static let maxBytes: UInt64 = 4_000_000

    // Everything below is touched only on `queue`.
    private let queue = DispatchQueue(label: "ai.sahha.sdk.wakecheck.log")
    private let formatter: DateFormatter
    private var handle: FileHandle?
    private var pipe: Pipe?
    private var originalStdout: Int32 = -1
    private var partialLine = Data()
    private var secrets: [String] = []

    private init() {
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    /// Values to blank out wherever they appear, such as the app secret given at launch.
    func redact(_ values: [String]) {
        queue.sync { secrets.append(contentsOf: values.filter { !$0.isEmpty }) }
    }

    func startCapturingStdout() {
        queue.sync {
            guard pipe == nil else { return }
            rotateIfLarge()
            // A pipe is fully buffered by default, so a line could sit in memory until
            // the process is suspended or ended. Line buffering sends each one at once.
            setvbuf(stdout, nil, _IOLBF, 0)
            originalStdout = dup(STDOUT_FILENO)
            let pipe = Pipe()
            dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard let self, !data.isEmpty else { return }
                let arrived = Date()
                self.queue.async { self.consumeStdout(data, arrivedAt: arrived) }
            }
            self.pipe = pipe
        }
    }

    /// Records one of the wake check's own events.
    func record(_ message: String) {
        let now = Date()
        queue.async { self.write("[WakeCheck] \(message)", at: now, echo: true) }
    }

    /// Up to the last `count` lines, oldest first.
    func tail(_ count: Int) -> [String] {
        queue.sync {
            guard let reader = try? FileHandle(forReadingFrom: Self.fileURL) else { return [] }
            defer { try? reader.close() }
            let size = (try? reader.seekToEnd()) ?? 0
            let window: UInt64 = 64_000
            try? reader.seek(toOffset: size > window ? size - window : 0)
            let data = (try? reader.readToEnd()) ?? Data()
            let lines = String(decoding: data, as: UTF8.self)
                .split(separator: "\n", omittingEmptySubsequences: true)
            return lines.suffix(count).map(String.init)
        }
    }

    func clear() {
        queue.sync {
            try? handle?.close()
            handle = nil
            try? FileManager.default.removeItem(at: Self.fileURL)
        }
    }

    /// Waits until everything recorded so far is in the file.
    func flush() {
        queue.sync { try? handle?.synchronize() }
    }

    // MARK: - On the queue

    private func consumeStdout(_ data: Data, arrivedAt date: Date) {
        if originalStdout >= 0 {
            data.withUnsafeBytes { _ = Darwin.write(originalStdout, $0.baseAddress, $0.count) }
        }
        partialLine.append(data)
        while let newline = partialLine.firstIndex(of: UInt8(ascii: "\n")) {
            let line = String(decoding: partialLine[partialLine.startIndex..<newline], as: UTF8.self)
            partialLine.removeSubrange(partialLine.startIndex...newline)
            if !line.isEmpty { write(line, at: date, echo: false) }
        }
    }

    private func write(_ line: String, at date: Date, echo: Bool) {
        let data = Data("\(formatter.string(from: date)) \(redacted(line))\n".utf8)
        if echo, originalStdout >= 0 {
            data.withUnsafeBytes { _ = Darwin.write(originalStdout, $0.baseAddress, $0.count) }
        }
        try? openHandle()?.write(contentsOf: data)
    }

    private func redacted(_ line: String) -> String {
        var line = line
        // "[Sahha Network] POST https://… | Headers: [...]": the headers carry the app
        // secret (sign-in) or the profile token (everything else).
        if let headers = line.range(of: " | Headers: ") {
            line = String(line[..<headers.lowerBound]) + " | Headers: (removed)"
        }
        for secret in secrets {
            line = line.replacingOccurrences(of: secret, with: "(redacted)")
        }
        // Any JWT, such as a profile token, that turns up anywhere else.
        return line.replacingOccurrences(
            of: #"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"#,
            with: "(token)",
            options: .regularExpression
        )
    }

    private func openHandle() -> FileHandle? {
        if let handle { return handle }
        let url = Self.fileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            // Writable even before the first unlock after a restart, so a background launch
            // then is logged too (MANUAL_CHECKLIST.md item 2). The log holds no credentials
            // or health values, only events, counts and URLs.
            FileManager.default.createFile(
                atPath: url.path,
                contents: nil,
                attributes: [.protectionKey: FileProtectionType.none]
            )
        } else {
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.none], ofItemAtPath: url.path
            )
        }
        handle = try? FileHandle(forWritingTo: url)
        _ = try? handle?.seekToEnd()
        return handle
    }

    private func rotateIfLarge() {
        let url = Self.fileURL
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
        guard size > Self.maxBytes else { return }
        let previous = url.deletingLastPathComponent().appendingPathComponent("wake-check.previous.log")
        try? FileManager.default.removeItem(at: previous)
        try? FileManager.default.moveItem(at: url, to: previous)
    }
}
