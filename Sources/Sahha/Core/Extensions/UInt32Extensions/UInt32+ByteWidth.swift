extension UInt32 {
    static var byteWidth: Int { MemoryLayout<Self>.size }
}
