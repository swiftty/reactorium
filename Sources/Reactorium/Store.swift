import Foundation
import struct SwiftUI.Binding
import struct SwiftUI.ObservedObject
@preconcurrency import Combine

@MainActor
public class Store<State: Sendable, Action, Dependency>: ObservableObject {
    @Bindable public var state: State

    public var reducer: any Reducer<State, Action, Dependency> {
        get { impl.reducer }
    }

    public var dependency: Dependency {
        get { impl.dependency }
        set { impl.dependency = newValue }
    }

    public let objectWillChange: ObservableObjectPublisher

    // MARK: -
    @usableFromInline
    let impl: any StoreImpl<State, Action, Dependency>

    // MARK: -
    public init(
        initialState: State,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency,
        removeDuplicates isDuplicate: ((State, State) -> Bool)? = nil
    ) {
        impl = RootStore(initialState: initialState, reducer: reducer,
                         dependency: dependency, removeDuplicates: isDuplicate)
        objectWillChange = impl.objectWillChange
    }

    public init<PState: Sendable, PAction, PDependency>(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency,
        removeDuplicates isDuplicate: ((State, State) -> Bool)? = nil
    ) {
        impl = ChildStore(binding: binder, action: action, reducer: reducer,
                          dependency: dependency, removeDuplicates: isDuplicate)
        objectWillChange = impl.objectWillChange
    }

    @inlinable
    @discardableResult
    public func send(_ newAction: Action) -> ActionTask {
        impl.send(newAction)
    }

    @inlinable
    public func send(_ newAction: Action, while predicate: @escaping @Sendable (State) -> Bool) async {
        await impl.send(newAction, while: predicate)
    }

    @inlinable
    public func binding<V>(get getter: @escaping (State) -> V, set setter: @escaping (V) -> Action) -> Binding<V> {
        ObservedObject(wrappedValue: self)
            .projectedValue[get: .init(value: getter), set: .init(value: setter)]
    }

    @usableFromInline
    func yield(while predicate: @escaping @Sendable (State) -> Bool) async {
        await impl.yield(while: predicate)
    }

    @usableFromInline
    subscript <V> (get getter: HashableWrapper<(State) -> V>, set setter: HashableWrapper<(V) -> Action>) -> V {
        get { getter.value(state) }
        set { send(setter.value(newValue)) }
    }
}

extension Store where State: Equatable {
    public convenience init(
        initialState: State,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency
    ) {
        self.init(initialState: initialState, reducer: reducer,
                  dependency: dependency, removeDuplicates: ==)
    }

    public convenience init<PState: Sendable, PAction, PDependency>(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency
    ) {
        self.init(binding: binder, action: action, reducer: reducer,
                  dependency: dependency, removeDuplicates: ==)
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
@usableFromInline
struct HashableWrapper<V>: Hashable, @unchecked Sendable {
    let value: V

    @usableFromInline
    init(value: V) {
        self.value = value
    }

    @usableFromInline
    static func == (lhs: Self, rhs: Self) -> Bool { true }

    @usableFromInline
    func hash(into hasher: inout Hasher) {}
}
