import Foundation
@preconcurrency import Combine

@MainActor
public class Store<State: Sendable, Action, Dependency>: ObservableObject {
    public var state: State { _state.value }

    // MARK: -
    @usableFromInline
    private(set) var cancellables: AnyCancellable? = nil

    @usableFromInline
    var bufferdActions: [Action] = []

    @usableFromInline
    var isSending = false

    var dependency: Dependency

    let _state: CurrentValueSubject<State, Never>
    let reducer: any Reducer<State, Action, Dependency>

    // MARK: -
    init(
        initialState: State,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency,
        removeDuplicates isDuplicate: ((State, State) -> Bool)? = nil
    ) {
        _state = .init(initialState)
        self.reducer = reducer
        self.dependency = dependency

        if let isDuplicate {
            cancellables = _state
                .removeDuplicates(by: isDuplicate)
                .sink { [weak self] _ in
                    assert(Thread.isMainThread)
                    self?.objectWillChange.send()
                }
        } else {
            cancellables = _state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    assert(Thread.isMainThread)
                    self?.objectWillChange.send()
                }
        }
    }

    @inlinable
    @discardableResult
    public func send(_ newAction: Action) -> ActionTask {
        let task = _send(newAction, from: nil)
        return ActionTask(task: task)
    }

    @inlinable
    public func send(_ newAction: Action, while predicate: @escaping @Sendable (State) -> Bool) async {
        let task = send(newAction)
        await Task.detached { [weak self] in
            await withTaskCancellationHandler {
                await self?._yield(while: predicate)
            } onCancel: {
                Task {
                    await task.cancel()
                }
            }
        }.value
    }

    @usableFromInline
    func _send(_ newAction: Action, from originalAction: Action?) -> Task<Void, Never>? {
        bufferdActions.append(newAction)
        guard !isSending else { return nil }

        isSending = true
        var currentState = _state.value

        var tasks: [Task<Void, Never>] = []
        defer {
            bufferdActions.removeAll()
            _state.value = currentState
            isSending = false
            assert(bufferdActions.isEmpty)
        }

        let dependency = dependency
        var index = bufferdActions.startIndex
        while index < bufferdActions.endIndex {
            defer { index += 1 }

            let newAction = bufferdActions[index]
            let effect = reducer.reduce(into: &currentState, action: newAction, dependency: dependency)

            switch effect.operation {
            case .none:
                break

            case .task(let priority, let runner):
                tasks.append(Task(priority: priority) { [weak self] in
                    await runner(Effect.Send {
                        if let task = self?._send($0, from: newAction) {
                            tasks.append(task)
                        }
                    })
                })
            }
        }

        guard !tasks.isEmpty else { return nil }

        return Task.detached {
            await withTaskCancellationHandler { @MainActor in
                var i = tasks.startIndex
                while i < tasks.endIndex {
                    defer { i += 1 }
                    await tasks[i].value
                }
            } onCancel: {
                Task { @MainActor in
                    var i = tasks.startIndex
                    while i < tasks.endIndex {
                        defer { i += 1 }
                        tasks[i].cancel()
                    }
                }
            }
        }
    }

    @usableFromInline
    func _yield(while predicate: @escaping @Sendable (State) -> Bool) async {
        if #available(iOS 15, macOS 12, *) {
            for await state in _state.values where !predicate(state) {
                return
            }
        } else {
            let state = _state
            let context = YieldContext()
            Task.detached {
                try? await withTaskCancellationHandler {
                    try Task.checkCancellation()
                    _ = try await context.register(state.filter { !predicate($0) })
                } onCancel: {
                    Task {
                        await context.cancel()
                    }
                }
            }
        }
    }
}

extension Store where State: Equatable {
    convenience init(
        initialState: State,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency
    ) {
        self.init(initialState: initialState, reducer: reducer, dependency: dependency, removeDuplicates: ==)
    }
}

extension Store {
    public struct ActionTask: Hashable, Sendable {
        let task: Task<Void, Never>?

        @usableFromInline
        init(task: Task<Void, Never>?) {
            self.task = task
        }

        public var isCancelled: Bool {
            task?.isCancelled ?? false
        }

        public func cancel() async {
            task?.cancel()
            await finish()
        }

        public func finish() async {
            await withTaskCancellationHandler {
                await task?.value
            } onCancel: {
                task?.cancel()
            }
        }
    }
}

public typealias StoreOf<R: Reducer> = Store<R.State, R.Action, R.Dependency>

// MARK: -
actor YieldContext {
    private var cancellable: AnyCancellable?

    func register<T>(_ values: some Publisher<T, Never>) async throws -> T {
        cancel()
        return try await withUnsafeThrowingContinuation { continuation in
            if Task.isCancelled {
                continuation.resume(throwing: CancellationError())
            }
            cancellable = values
                .prefix(1)
                .sink { value in
                    continuation.resume(returning: value)
                }
        }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}
