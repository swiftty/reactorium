import SwiftUI

// MARK: -
extension View {
    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Sendable, Action, Dependency
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency
    ) -> some View {
        scope(key: binder.value.id, binding: binder, action: action, reducer: reducer, dependency: dependency)
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Sendable, Action
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>
    ) -> some View {
        scope(key: binder.value.id, binding: binder, action: action, reducer: reducer)
    }

    // MARK: with equatable
    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Equatable & Sendable, Action, Dependency
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency
    ) -> some View {
        scope(key: binder.value.id, binding: binder, action: action, reducer: reducer, dependency: dependency)
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Equatable & Sendable, Action
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>
    ) -> some View {
        scope(key: binder.value.id, binding: binder, action: action, reducer: reducer)
    }
}

// MARK: - for optional
extension View {
    @MainActor
    @ViewBuilder
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Sendable, Action, Dependency,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder else elseContent: () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: binder.value?.id, binding: binder, action: action, reducer: reducer, dependency: dependency, else: elseContent)
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Sendable, Action,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder else elseContent: () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: binder.value?.id, binding: binder, action: action, reducer: reducer, else: elseContent)
    }

    // MARK: with equatable
    @MainActor
    @ViewBuilder
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Equatable & Sendable, Action, Dependency,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder else elseContent: () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: binder.value?.id, binding: binder, action: action, reducer: reducer, dependency: dependency, else: elseContent)
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Equatable & Sendable, Action,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder else elseContent: () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: binder.value?.id, binding: binder, action: action, reducer: reducer, else: elseContent)
    }
}

// MARK: - for optional with custom layout
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Layout {
    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Sendable, Action, Dependency,
        ThenContent: View,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder then thenContent: @escaping () -> ThenContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: binder.value?.id, binding: binder, action: action, reducer: reducer, dependency: dependency,
              then: thenContent, else: elseContent)
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Sendable, Action,
        ThenContent: View,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder then thenContent: @escaping () -> ThenContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: binder.value?.id, binding: binder, action: action, reducer: reducer,
              then: thenContent, else: elseContent)
    }

    // MARK: with equatable
    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Equatable & Sendable, Action, Dependency,
        ThenContent: View,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder then thenContent: @escaping () -> ThenContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: binder.value?.id, binding: binder, action: action, reducer: reducer, dependency: dependency,
              then: thenContent, else: elseContent)
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Identifiable & Equatable & Sendable, Action,
        ThenContent: View,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder then thenContent: @escaping () -> ThenContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: binder.value?.id, binding: binder, action: action, reducer: reducer,
              then: thenContent, else: elseContent)
    }
}
