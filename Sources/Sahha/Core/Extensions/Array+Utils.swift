import Foundation

extension Array where Element: Sendable {
    func concurrentMap<T: Sendable>(_ transform: @Sendable @escaping (Element) async -> T?) async -> [T] {
          await withTaskGroup(of: T?.self) { group in
              for element in self {
                  group.addTask { await transform(element) }
              }

              var results = ContiguousArray<T>()
              for await result in group {
                  if let value = result {
                      results.append(value)
                  }
              }
              return Array<T>(results)
          }
      }
    
    func concurrentFlatMap<T: Sendable>(_ transform: @Sendable @escaping (Element) async -> [T]?) async -> [T] {
           await withTaskGroup(of: [T]?.self) { group in
               for element in self {
                   group.addTask { await transform(element) }
               }

               var results = ContiguousArray<T>()
               for await result in group {
                   if let items = result {
                       results.append(contentsOf: items)
                   }
               }
               return Array<T>(results)
           }
       }
}

extension Array where Element: Encodable {
    private struct DataWrapper: Encodable {
        let data: [Element]
    }
    
    func toDataWrappedJSON() throws -> String {
        let wrapper = DataWrapper(data: self)
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(wrapper)
        return String(data: jsonData, encoding: .utf8)!
    }
}
