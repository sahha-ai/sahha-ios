protocol DataLogProcessorProtocol: Processor where Input == [any DataLogType] {}

actor DataLogProcessor: DataLogProcessorProtocol {
    func processData(_ input: [any DataLogType]) async {
        print("Processing \(input.count) data logs")
    }
    
    func isAcceptingData() async -> Bool {
        return true
    }
}
