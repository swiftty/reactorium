import SwiftUI
@preconcurrency import Combine

@MainActor
class ChildStore<
    PState: Sendable, PAction, PDependency,
    State: Sendable, Action, Dependency
>: StoreImpl {
    var state: State { scope(parent.state) }
    let reducer: any Reducer<State, Action, Dependency>
    var dependency: Dependency
    let objectWillChange = ObservableObjectPublisher()

    let parent: any StoreImpl<PState, PAction, PDependency>
    let scope: (PState) -> State
    let action: (State) -> PAction

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
        self.reducer = reducer
        self.dependency = dependency
    }

    @usableFromInline
    func send(_ newAction: @escaping @MainActor (State, Tasks) -> Action) -> Task<Void, Never>? {
        return parent.send({ [self] state, tasks in
            var state = scope(state)
            let newAction = newAction(state, tasks)
            let effect = reducer.reduce(into: &state, action: newAction, dependency: dependency)

            objectWillChange.send()

            switch effect.operation {
            case .none:
                break

            case .task(let priority, let runner):
                tasks.append(Task(priority: priority) { [weak self] in
                    await runner(Effect.Send { action in
                        guard let self else { return }
                        let task = self.send({ _, _ in action })
                        assert(task == nil)
                    })
                })
            }

            return action(state)
        })
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
