import Combine

//public extension Publisher {
//    /// Extracts values from a publisher as an async stream to use it with async/await calls.
//    func values() -> AsyncThrowingStream<Output, Error> {
//        .init { continuation in
//            let cancellation = self.sink { completion in
//                switch completion {
//                case .finished:
//                    continuation.finish()
//                case let .failure(error):
//                    continuation.finish(throwing: error)
//                }
//            } receiveValue: { value in
//                continuation.yield(value)
//            }
//
//            continuation.onTermination = { _ in
//                cancellation.cancel()
//            }
//        }
//    }
//}
