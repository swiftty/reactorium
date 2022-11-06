import SwiftUI

extension Store {
    @inlinable
    @discardableResult
    public func send(_ newAction: Action, animation: Animation?) -> ActionTask {
        withAnimation(animation) {
            send(newAction)
        }
    }

    @inlinable
    public func send(_ newAction: Action, animation: Animation?, while predicate: @escaping @Sendable (State) -> Bool) async {
        let task = send(newAction, animation: animation)
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
}

extension Store {
    public func binding<V>(get getter: @escaping (State) -> V, set setter: @escaping (V) -> Action) -> Binding<V> {
        ObservedObject(wrappedValue: self)
            .projectedValue[get: .init(value: getter), set: .init(value: setter)]
    }

    private subscript <V> (get getter: HashableWrapper<(State) -> V>, set setter: HashableWrapper<(V) -> Action>) -> V {
        get { getter.value(state) }
        set { send(setter.value(newValue)) }
    }
}

// MARK: -
extension View {
    @MainActor
    public func store<S: Sendable, A, D>(
        initialState: @escaping @autoclosure () -> S,
        reducer: some Reducer<S, A, D>,
        dependency: @escaping (EnvironmentValues) -> D
    ) -> some View {
        modifier(StoreInjector(dependency: dependency) { dependency in
            Store(initialState: initialState(), reducer: reducer, dependency: dependency)
        })
    }

    @MainActor
    public func store<S: Equatable & Sendable, A, D>(
        initialState: @escaping @autoclosure () -> S,
        reducer: some Reducer<S, A, D>,
        dependency: @escaping (EnvironmentValues) -> D
    ) -> some View {
        modifier(StoreInjector(dependency: dependency) { dependency in
            Store(initialState: initialState(), reducer: reducer, dependency: dependency, removeDuplicates: ==)
        })
    }
}

extension View {
    @MainActor
    public func store<S: Sendable, A>(
        initialState: @escaping @autoclosure () -> S,
        reducer: some Reducer<S, A, Void>
    ) -> some View {
        modifier(StoreInjector(dependency: { _ in }) { dependency in
            Store(initialState: initialState(), reducer: reducer, dependency: dependency)
        })
    }

    @MainActor
    public func store<S: Equatable & Sendable, A>(
        initialState: @escaping @autoclosure () -> S,
        reducer: some Reducer<S, A, Void>
    ) -> some View {
        modifier(StoreInjector(dependency: { _ in }) { dependency in
            Store(initialState: initialState(), reducer: reducer, dependency: dependency, removeDuplicates: ==)
        })
    }
}

// MARK: -
struct StoreInjector<State: Sendable, Action, Dependency>: EnvironmentalModifier {
    struct Modifier: ViewModifier {
        @StateObject var store: Store<State, Action, Dependency>
        let dependency: Dependency

        func body(content: Content) -> some View {
            store.dependency = dependency
            return content
                .environmentObject(store)
        }
    }

    let dependency: (EnvironmentValues) -> Dependency
    let inject: (Dependency) -> Store<State, Action, Dependency>

    func resolve(in environment: EnvironmentValues) -> some ViewModifier {
        let dependency = dependency(environment)
        return Modifier(
            store: inject(dependency),
            dependency: dependency
        )
    }
}

struct HashableWrapper<V>: Hashable, @unchecked Sendable {
    let value: V

    static func == (lhs: Self, rhs: Self) -> Bool { true }
    func hash(into hasher: inout Hasher) {}
}
