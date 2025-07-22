// Drop-in AsyncChannel implementation using Swift's concurrency features.
// This is a bounded channel that provides backpressure by suspending senders when full
// and receivers when empty. It uses an actor for safety and CheckedContinuation for suspension.

actor AsyncChannel<T: Sendable> {
    private var buffer: [T] = []
    private let maxSize: Int
    private var isFinished: Bool = false
    private var sendWaiters: [CheckedContinuation<Void, Never>] = []
    private var receiveWaiters: [CheckedContinuation<T?, Never>] = []  // Optional T to handle finish

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    /// Send a value to the channel. Suspends if the buffer is full until space is available.
    func send(_ value: T) async {
        guard !isFinished else { return }  // Ignore sends after finish

        if buffer.count < maxSize {
            buffer.append(value)
            signalReceiverIfNeeded()
        } else {
            await withCheckedContinuation { cont in
                sendWaiters.append(cont)
            }
            if !isFinished {
                buffer.append(value)
                signalReceiverIfNeeded()
            }
        }
    }

    /// Receive a value from the channel. Suspends if empty until a value is available or finished.
    /// Returns nil if the channel is finished and buffer is empty.
    func receive() async -> T? {
        if !buffer.isEmpty {
            let value = buffer.removeFirst()
            signalSenderIfNeeded()
            return value
        } else if isFinished {
            return nil
        } else {
            return await withCheckedContinuation { cont in
                receiveWaiters.append(cont)
            }
        }
    }

    /// Mark the channel as finished. No more sends accepted, and pending/future receives will get nil once buffer empties.
    func finish() {
        isFinished = true
        // Wake receivers with nil
        while let waiter = receiveWaiters.first {
            receiveWaiters.removeFirst()
            waiter.resume(returning: nil)
        }
        // Wake senders (though they shouldn't send after finish)
        while let waiter = sendWaiters.first {
            sendWaiters.removeFirst()
            waiter.resume()
        }
    }

    private func signalSenderIfNeeded() {
        if buffer.count < maxSize, let waiter = sendWaiters.first {
            sendWaiters.removeFirst()
            waiter.resume()
        }
    }

    private func signalReceiverIfNeeded() {
        if !buffer.isEmpty, let waiter = receiveWaiters.first {
            receiveWaiters.removeFirst()
            let value = buffer.removeFirst()
            waiter.resume(returning: value)
            signalSenderIfNeeded()
        } else if isFinished, let waiter = receiveWaiters.first {
            receiveWaiters.removeFirst()
            waiter.resume(returning: nil)
        }
    }
}
