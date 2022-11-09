import SwiftUI

// MARK: -
extension View {
    @MainActor
    public func store<S: Sendable, A, D>(
        initialState: @escaping @autoclosure () -> S,
        reducer: some Reducer<S, A, D>,
        dependency: @escaping (EnvironmentValues) -> D
    ) -> some View {
        modifier(StateEnvironmentResolver(dependency: dependency) { dependency in
            Store(initialState: initialState(), reducer: reducer, dependency: dependency)
        })
    }

    @MainActor
    public func store<S: Equatable & Sendable, A, D>(
        initialState: @escaping @autoclosure () -> S,
        reducer: some Reducer<S, A, D>,
        dependency: @escaping (EnvironmentValues) -> D
    ) -> some View {
        modifier(StateEnvironmentResolver(dependency: dependency) { dependency in
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
        store(initialState: initialState(), reducer: reducer, dependency: { _ in })
    }

    @MainActor
    public func store<S: Equatable & Sendable, A>(
        initialState: @escaping @autoclosure () -> S,
        reducer: some Reducer<S, A, Void>
    ) -> some View {
        store(initialState: initialState(), reducer: reducer, dependency: { _ in })
    }
}

// MARK: -
private struct StateEnvironmentResolver<State: Sendable, Action, Dependency>: EnvironmentalModifier {
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
