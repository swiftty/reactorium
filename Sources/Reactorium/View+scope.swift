import SwiftUI

// MARK: -
extension View {
    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action, Dependency
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency
    ) -> some View {
        modifier(ObservedEnvironmentResolver(dependency: dependency) { dependency in
            Store(binding: binder, action: action, reducer: reducer, dependency: dependency)
        })
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>
    ) -> some View {
        scope(binding: binder, action: action, reducer: reducer, dependency: { _ in })
    }
}

extension View {
    @MainActor
    @ViewBuilder
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action, Dependency,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder else elseContent: () -> ElseContent = { EmptyView() }
    ) -> some View {
        if let value = binder.value {
            scope(binding: binder.map { $0 ?? value }, action: action, reducer: reducer, dependency: dependency)
        } else {
            elseContent()
        }
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder else elseContent: () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(binding: binder, action: action, reducer: reducer, dependency: { _ in }, else: elseContent)
    }
}

// MARK: -
private struct ObservedEnvironmentResolver<State: Sendable, Action, Dependency>: EnvironmentalModifier {
    struct Modifier: ViewModifier {
        @ObservedObject var store: Store<State, Action, Dependency>
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
