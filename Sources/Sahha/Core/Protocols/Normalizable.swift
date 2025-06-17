protocol Normalizable {
    associatedtype RawData
    associatedtype LogType
    func normalize(_ rawData: RawData) async -> LogType?
}
