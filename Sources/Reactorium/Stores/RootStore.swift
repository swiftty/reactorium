import SwiftUI
@preconcurrency import Combine

@MainActor
class RootStore<State: Sendable, Action, Dependency>: StoreImpl {
    var state: State { _state.value }
    let reducer: any Reducer<State, Action, Dependency>
    var dependency: Dependency
    let objectWillChange = ObservableObjectPublisher()

    let _state: CurrentValueSubject<State, Never>
    let isDuplicate: ((State, State) -> Bool)?

    @usableFromInline
    private(set) var cancellables: AnyCancellable? = nil

    @usableFromInline
    var bufferdActions: [@MainActor (State, Tasks) -> Action] = []

    @usableFromInline
    var isSending = false

    @usableFromInline
    var runningTasks: Set<Task<Void, Never>> = []

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
        self.isDuplicate = isDuplicate
    }

    deinit {
        runningTasks.forEach { $0.cancel() }
    }

    // MARK: -
    @usableFromInline
    func send(_ newAction: @escaping @MainActor (State, Tasks) -> Action) -> Task<Void, Never>? {
        bufferdActions.append(newAction)
        guard !isSending else { return nil }

        isSending = true
        var currentState = _state.value

        let tasks = Tasks()
        defer {
            bufferdActions.removeAll()
            let fire: Bool = {
                guard let isDuplicate else { return true }
                return !isDuplicate(_state.value, currentState)
            }()
            if fire {
                objectWillChange.send()
            }
            _state.value = currentState
            isSending = false
            assert(bufferdActions.isEmpty)
        }

        let dependency = dependency
        var index = bufferdActions.startIndex
        while index < bufferdActions.endIndex {
            defer { index += 1 }

            let newAction = bufferdActions[index](currentState, tasks)
            let effect = reducer.reduce(into: &currentState, action: newAction, dependency: dependency)

            switch effect.operation {
            case .none:
                break

            case .task(let priority, let runner):
                tasks.append(Task(priority: priority) { [weak self] in
                    await runner(Effect.Send { action in
                        let task = self?.send({ _, _ in action })
                        assert(task == nil)
                    })
                })
            }
        }

        guard !tasks.isEmpty else { return nil }

        let task =  Task.detached {
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
        runningTasks.insert(task)
        Task { [weak self] in
            await task.value
            self?.runningTasks.remove(task)
        }
        return task
    }

    // MARK: -
    @usableFromInline
    func yield(while predicate: @escaping @Sendable (State) -> Bool) async {
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

    func binding<V>(get getter: @escaping (State) -> V, set setter: @escaping (V) -> Action) -> Binding<V> {
        ObservedObject(wrappedValue: self)
            .projectedValue[get: .init(value: getter), set: .init(value: setter)]
    }

    private subscript <V> (get getter: HashableWrapper<(State) -> V>, set setter: HashableWrapper<(V) -> Action>) -> V {
        get { getter.value(state) }
        set { send(setter.value(newValue)) }
    }
}

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

private struct HashableWrapper<V>: Hashable, @unchecked Sendable {
    let value: V

    static func == (lhs: Self, rhs: Self) -> Bool { true }
    func hash(into hasher: inout Hasher) {}
}
