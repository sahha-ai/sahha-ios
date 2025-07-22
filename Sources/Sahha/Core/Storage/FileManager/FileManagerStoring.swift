import Foundation

protocol FileManagerStoring: Actor {
    /// Write a codable object to file, returns file URL
    func write<T: Encodable>(_ object: T, filename: String, fileExtension: String) throws -> URL
    
    /// Read a codable object from file URL
    func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T

    /// Delete a file at URL
    func delete(at url: URL) throws

    /// List all files (optionally by extension)
    func listFiles(withExtension ext: String?) throws -> [URL]
}
