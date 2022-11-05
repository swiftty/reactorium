import Foundation

extension Effect {
    @inlinable
    public func map<T>(_ transform: @escaping @Sendable (Action) -> T) -> Effect<T> {
        switch operation {
        case .none:
            return nil

        case .task(let priority, let body):
            return .init(operation: .task(priority) { send in
                await body(Send { action in
                    send(transform(action))
                })
            })
        }
    }
}
