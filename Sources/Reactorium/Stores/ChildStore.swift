import SwiftUI
@preconcurrency import Combine

@MainActor
class ChildStore<
    PState: Sendable, PAction, PDependency,
    State: Sendable, Action, Dependency
>: StoreImpl {
    var state: State { _state.wrappedValue }
    let reducer: any Reducer<State, Action, Dependency>
    var dependency: Dependency
    let objectWillChange = ObservableObjectPublisher()

    var _state: Binding<State> { binder(action: action) }
    let binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>
    let action: (State) -> PAction

    @usableFromInline
    var bufferdActions: [@MainActor (State, Tasks) -> Action] = []

    @usableFromInline
    var isSending = false

    @usableFromInline
    var runningTasks: Set<Task<Void, Never>> = []

    init(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency
    ) {
        self.binder = binder
        self.action = action
        self.reducer = reducer
        self.dependency = dependency
    }

    deinit {
        runningTasks.forEach { $0.cancel() }
    }

    @usableFromInline
    func send(_ newAction: @escaping @MainActor (State, Tasks) -> Action) -> Task<Void, Never>? {
        bufferdActions.append(newAction)
        guard !isSending else { return nil }

        isSending = true
        var currentState = _state.wrappedValue

        let tasks = Tasks()
        defer {
            bufferdActions.removeAll()
            objectWillChange.send()
            _state.wrappedValue = currentState
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
                    guard !Task.isCancelled else { return }
                    await runner(Effect.Send { action in
                        let task = self?.send({ _, _ in action })
                        assert(task == nil)
                    })
                })
            }
        }

        guard !tasks.isEmpty else { return nil }

        let task = Task.detached {
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

    @usableFromInline
    func yield(while predicate: @escaping @Sendable (State) -> Bool) async {
        let scope = ScopeWrapper(value: binder.getter)
        await binder.store.yield(while: { predicate(scope.value($0)) })
    }

    func binding<V>(get getter: @escaping (State) -> V, set setter: @escaping (V) -> Action) -> Binding<V> {
        Binding {
            getter(self.state)
        } set: { newValue in
            self.send(setter(newValue))
        }
    }
}

struct ScopeWrapper<Root, Value>: @unchecked Sendable {
    let value: (Root) -> Value
}
