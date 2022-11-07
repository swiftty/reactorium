import Foundation
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
        impl = RootStore(initialState: initialState, reducer: reducer, dependency: dependency, removeDuplicates: isDuplicate)
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

    @usableFromInline
    func yield(while predicate: @escaping @Sendable (State) -> Bool) async {
        await impl.yield(while: predicate)
    }
}

extension Store where State: Equatable {
    public convenience init(
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
