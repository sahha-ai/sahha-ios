final actor AsyncSemaphore {
    private var value: Int
    private let maxValue: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = max(0, value)
        self.maxValue = max(0, value)
    }

    func wait() async {
        if value > 0 {
            value -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else if value < maxValue {
            value += 1
        }
    }
    
    func waitForAll() async {
        while waiters.notEmpty || value < maxValue {
            await wait()
        }
    }
}
