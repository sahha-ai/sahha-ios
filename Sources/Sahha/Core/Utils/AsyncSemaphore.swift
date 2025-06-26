actor AsyncSemaphore {
    private var count: Int
    private let maxCount: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.count = max(0, value)
        self.maxCount = max(0, value)
    }

    func wait() async {
        if count > 0 {
            count -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            continuation.resume()
        } else {
            count += 1
        }
    }

    func waitForAll() async {
        while !waiters.isEmpty || count < maxCount {
            await wait()
        }
    }
}
