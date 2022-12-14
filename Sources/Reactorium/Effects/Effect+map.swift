import Foundation

extension Effect {
    @inlinable
    public func map<T>(_ transform: @escaping @Sendable (Action) -> T) -> Effect<T> {
        return map { body in
            return { send in
                await body(Send { action in
                    send(transform(action))
                })
            }
        }
    }

    @inlinable
    public func map<T>(
        _ transform: (@escaping @Sendable @MainActor (Send) async -> Void) -> @Sendable @MainActor (Effect<T>.Send) async -> Void
    ) -> Effect<T> {
        switch operation {
        case .none:
            return nil

        case .task(let priority, let body):
            return .init(operation: .task(priority, body: transform(body)))
        }
    }
}
