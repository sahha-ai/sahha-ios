import Foundation

extension Array where Element: Sendable {
    func concurrentCompactMap<T: Sendable>(
          _ transform: @Sendable @escaping (Element) async -> T?
      ) async -> [T] {
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
    
    func concurrentFlatMap<T: Sendable>(
           _ transform: @Sendable @escaping (Element) async -> [T]?
       ) async -> [T] {
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
