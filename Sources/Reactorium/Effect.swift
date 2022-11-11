import Foundation

public struct Effect<Action> {
    @usableFromInline
    typealias TaskBody = @Sendable @MainActor (Send) async -> Void

    @usableFromInline
    enum Operation {
        case none
        case task(TaskPriority? = nil, body: TaskBody)
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
        operation body: @escaping @Sendable @MainActor (Send) async -> Void
    ) -> Self {
        .init(operation: .task(priority, body: body))
    }

    @inlinable
    public static func task(
        priority: TaskPriority? = nil,
        operation body: @escaping @Sendable @MainActor (Send) async throws -> Void,
        catch errorBody: @escaping @Sendable @MainActor (Error, Send) async -> Void
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
}
