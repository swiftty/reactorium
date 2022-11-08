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

    let parent: any StoreImpl<PState, PAction, PDependency>
    let _state: Binding<State>
    let scope: (PState) -> State
    let action: (State) -> PAction

    @usableFromInline
    var bufferdActions: [Action] = []

    @usableFromInline
    var isSending = false

    init(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency
    ) {
        let scope = binder.getter
        self.parent = binder.store.impl
        self.scope = scope
        self.action = action
        self._state = binder(action: action)
        self.reducer = reducer
        self.dependency = dependency
    }

    @usableFromInline
    func send(_ newAction: @escaping @MainActor (State, Tasks) -> Action, from originalAction: Action?) -> Task<Void, Never>? {
        return parent.send({ [self] state, tasks in
            var state = scope(state)
            let newAction = newAction(state, tasks)
            let effect = reducer.reduce(into: &state, action: newAction, dependency: dependency)

            switch effect.operation {
            case .none:
                break

            case .task(let priority, let runner):
                tasks.append(Task(priority: priority) {
                    await runner(Effect.Send { action in
                        let task = self.send({ _, _ in action }, from: newAction)
                        assert(task == nil)
                    })
                })
            }

            return action(state)
        }, from: nil)
    }

    @usableFromInline
    func yield(while predicate: @escaping @Sendable (State) -> Bool) async {
        let scope = ScopeWrapper(value: scope)
        await parent.yield(while: { predicate(scope.value($0)) })
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
