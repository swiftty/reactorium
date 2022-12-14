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

extension Effect {
    @inlinable
    public static func task(
        priority: TaskPriority? = nil,
        operation body: @escaping @Sendable (Send) async -> Void
    ) -> Self {
        .init(operation: .task(priority, body: body))
    }

    @inlinable
    public static func task(
        priority: TaskPriority? = nil,
        operation body: @escaping @Sendable (Send) async throws -> Void,
        catch errorBody: @escaping @Sendable (Error, Send) async -> Void
    ) -> Self {
        .init(operation: .task(priority) { send in
            do {
                try await body(send)
            } catch is CancellationError {
                return
            } catch {
                await errorBody(error, send)
            }
        })
    }
}

extension Effect: ExpressibleByNilLiteral {
    @inlinable
    public init(nilLiteral: ()) {
        self.init(operation: .none)
    }

    public static var none: Self { nil }
}
