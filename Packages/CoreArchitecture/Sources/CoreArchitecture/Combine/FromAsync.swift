import Combine

//public extension Future {
//    /// Derive a future from an async operation, derives Output and Failure from a Result type.
//    static func from(_ function: @escaping () async -> Result<Output, Failure>) -> Future<Output, Failure> {
//        .init { completion in
//            Task {
//                await completion(function())
//            }
//        }
//    }
//
//    // TODO: Swift 6 can provide a specific error
//    /// Derive a future from a failable async operation, defaults to any Error as the output error type.
//    static func from(_ function: @escaping () async throws -> Output) -> Future<Output, any Error> {
//        .init { completion in
//            Task {
//                do {
//                    try await completion(.success(function()))
//                } catch {
//                    completion(.failure(error))
//                }
//            }
//        }
//    }
//
//    /// Derive a future from a non-failable async operation.
//    @_disfavoredOverload static func from(_ function: @escaping () async -> Output) -> Future<Output, Never> {
//        .init { completion in
//            Task {
//                await completion(.success(function()))
//            }
//        }
//    }
//}
