import Foundation

public struct Effect<Action> {
    @usableFromInline
    enum Operation {
        case none
        case task(TaskPriority? = nil, body: @Sendable @MainActor (Send) async -> Void)
    }

    @usableFromInline
    let operation: Operation

    @usableFromInline
    init(operation: Operation) {
        self.operation = operation
    }
}

extension Effect: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.init(operation: .none)
    }
}

extension Effect {
    @MainActor
    public struct Send {
        let body: @MainActor (Action) -> Void

        public func callAsFunction(_ action: Action) {
            guard !Task.isCancelled else { return }
            body(action)
        }
    }
}
