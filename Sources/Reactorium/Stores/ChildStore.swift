import SwiftUI
@preconcurrency import Combine

@MainActor
class ChildStore<
    PState: Sendable, PAction, PDependency,
    State: Sendable, Action, Dependency
>: StoreImpl {
    var state: State {
        get { _state.wrappedValue }
        set {
            let fire: Bool = {
                guard let isDuplicate else { return true }
                return !isDuplicate(_state.wrappedValue, newValue)
            }()
            if fire {
                objectWillChange.send()
            }
            _state.wrappedValue = newValue
        }
    }
    let reducer: any Reducer<State, Action, Dependency>
    var dependency: Dependency
    let objectWillChange = ObservableObjectPublisher()

    var bufferdActions: [Action] = []
    var isSending = false
    var runningTasks: Set<Task<Void, Never>> = []

    private var _state: Binding<State> { binder(action: action) }
    private let binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>
    private let action: (State) -> PAction
    private let isDuplicate: ((State, State) -> Bool)?

    init(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency,
        removeDuplicates isDuplicate: ((State, State) -> Bool)? = nil
    ) {
        self.binder = binder
        self.action = action
        self.reducer = reducer
        self.dependency = dependency
        self.isDuplicate = isDuplicate
    }

    deinit {
        runningTasks.forEach { $0.cancel() }
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

// MARK: -
private struct ScopeWrapper<Root, Value>: @unchecked Sendable {
    let value: (Root) -> Value
}
