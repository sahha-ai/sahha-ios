import HealthKit

actor DataLogPipeline: DataPipeline {
    typealias Input = [DataLog]
    
    func processData(_ data: Input) async {
        // TODO
    }
    
    func isAcceptingData() async -> Bool {
        return true
    }
}
