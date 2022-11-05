import Foundation
@preconcurrency import Combine

extension Effect {
    @inlinable
    public func cancellable<I>(id: I.Type, cancelInFlight: Bool = false) -> Self {
        cancellable(id: ObjectIdentifier(id), cancelInFlight: cancelInFlight)
    }

    @inlinable
    public func cancellable(id: some Hashable & Sendable, cancelInFlight: Bool = false) -> Self {
        map { body in
            return { send in
                await withTaskCancellation(id: id, cancelInFlight: cancelInFlight) {
                    await body(send)
                }
            }
        }
    }

    @inlinable
    public func cancel<I>(id: I.Type) -> Self {
        cancel(id: ObjectIdentifier(id))
    }

    public func cancel(id: some Hashable & Sendable) -> Self {
        .init(operation: .task { _ in
            await _cancellables.cancel(by: .init(id: id))
        })
    }
}

// MARK: -
@inlinable
public func withTaskCancellation<I, T: Sendable>(
    id: I.Type,
    cancelInFlight: Bool = false,
    operation: @escaping @Sendable () async throws -> T
) async rethrows -> T {
    try await withTaskCancellation(
        id: ObjectIdentifier(id),
        cancelInFlight: cancelInFlight,
        operation: operation
    )
}

public func withTaskCancellation<T: Sendable>(
    id: some Hashable,
    cancelInFlight: Bool = false,
    operation: @escaping @Sendable () async throws -> T
) async rethrows -> T {
    let id = CancellableToken(id: id)
    if cancelInFlight {
        await _cancellables.cancel(by: id)
    }
    let (task, cancellable) = await _cancellables.append(operation, for: id)

    // return
    let result: Result<T, Error>
    do {
        let value = try await withThrowingTaskGroup(of: T.self, returning: T.self) { group in
            group.addTask {
                try await task.value
            }
            for try await value in group {
                return value
            }
            throw CancellationError()
        }
        result = .success(value)
    } catch {
        result = .failure(error)
    }

    // defer
    await _cancellables.resolve(cancellable, for: id)

    return try result._rethrowGet()
}

// MARK: - private
private struct CancellableToken: Hashable, @unchecked Sendable {
    let id: AnyHashable
    let base: ObjectIdentifier

    init<H: Hashable>(id: H) {
        self.base = ObjectIdentifier(H.self)
        self.id = id
    }
}

private actor Cancellables {
    var tasks: [CancellableToken: Set<AnyCancellable>] = [:]

    func cancel(by id: CancellableToken) {
        tasks[id]?.forEach { $0.cancel() }
    }

    func append<T>(
        _ operation: @escaping @Sendable () async throws -> T,
        for id: CancellableToken
    ) -> (Task<T, Error>, AnyCancellable) {
        let task = Task { try await operation() }
        let cancellable = AnyCancellable { task.cancel() }
        tasks[id, default: []].insert(cancellable)
        return (task, cancellable)
    }

    func resolve(
        _ cancellable: AnyCancellable,
        for id: CancellableToken
    ) {
        tasks[id]?.remove(cancellable)
        if tasks[id]?.isEmpty ?? false {
            tasks[id] = nil
        }
    }
}

private let _cancellables = Cancellables()

@rethrows
private protocol _ErrorMechanism {
  associatedtype Output
  func get() throws -> Output
}

extension _ErrorMechanism {
  func _rethrowError() rethrows -> Never {
    _ = try _rethrowGet()
    fatalError()
  }

  func _rethrowGet() rethrows -> Output {
    return try get()
  }
}

extension Result: _ErrorMechanism {}
