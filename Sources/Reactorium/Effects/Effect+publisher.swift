import Foundation
import Combine

extension Effect where Action: Sendable {
    @inlinable
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public static func publisher<P: Publisher & Sendable>(_ publisher: P) -> Self
    where P.Output == Action, P.Failure == Never {
        .init(operation: .task { send in
            guard !Task.isCancelled else { return }
            for await action in publisher.values {
                guard !Task.isCancelled else { break }
                send(action)
            }
        })
    }
}
