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
        modifier(ProxyModifier(dependency: dependency) { dependency in
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

    // MARK: with equatable
    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Sendable & Equatable, Action, Dependency
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency
    ) -> some View {
        modifier(ProxyModifier(dependency: dependency) { dependency in
            Store(binding: binder, action: action, reducer: reducer, dependency: dependency, removeDuplicates: ==)
        })
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Sendable & Equatable, Action
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>
    ) -> some View {
        scope(binding: binder, action: action, reducer: reducer, dependency: { _ in })
    }
}

// MARK: - for optional
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

    // MARK: with equatable
    @MainActor
    @ViewBuilder
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Sendable & Equatable, Action, Dependency,
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
        State: Sendable & Equatable, Action,
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

// MARK: - for optional with custom layout
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension View {
    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action, Dependency,
        Layout: SwiftUI.Layout,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() },
        in layout: Layout
    ) -> some View {
        modifier(OptionalProxyModifier(
            initialState: binder.value,
            dependency: dependency,
            inject: { dependency, state in
                Store(binding: binder.map { $0 ?? state }, action: action, reducer: reducer, dependency: dependency)
            },
            layout: layout,
            elseContent: elseContent)
        )
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action,
        Layout: SwiftUI.Layout,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() },
        in layout: Layout
    ) -> some View {
        scope(binding: binder, action: action, reducer: reducer, dependency: { _ in }, else: elseContent, in: layout)
    }

    // MARK: with equatable
    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Equatable & Sendable, Action, Dependency,
        Layout: SwiftUI.Layout,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() },
        in layout: Layout
    ) -> some View {
        modifier(OptionalProxyModifier(
            initialState: binder.value,
            dependency: dependency,
            inject: { dependency, state in
                Store(binding: binder.map { $0 ?? state }, action: action, reducer: reducer, dependency: dependency, removeDuplicates: ==)
            },
            layout: layout,
            elseContent: elseContent)
        )
    }

    @MainActor
    public func scope<
        PState: Sendable, PAction, PDependency,
        State: Equatable & Sendable, Action,
        Layout: SwiftUI.Layout,
        ElseContent: View
    >(
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() },
        in layout: Layout
    ) -> some View {
        scope(binding: binder, action: action, reducer: reducer, dependency: { _ in }, else: elseContent, in: layout)
    }
}

// MARK: -
private struct ProxyModifier<State: Sendable, Action, Dependency>: ViewModifier {
    @StateObject var proxy = ProxyStore<State, Action, Dependency>()
    let dependency: (EnvironmentValues) -> Dependency
    let inject: (Dependency) -> Store<State, Action, Dependency>

    func body(content: Content) -> some View {
        ZStack {
            DismantleView(proxy: proxy, dependency: dependency, inject: inject)
                .opacity(0)
                .frame(width: 0, height: 0)

            if let store = proxy.store {
                content
                    .environmentObject(store)
            }
        }
    }
}

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
private struct OptionalProxyModifier<
    State: Sendable, Action, Dependency,
    Layout: SwiftUI.Layout,
    ElseContent: View
>: ViewModifier {
    @StateObject var proxy = ProxyStore<State, Action, Dependency>()
    let initialState: State?
    let dependency: (EnvironmentValues) -> Dependency
    let inject: (Dependency, State) -> Store<State, Action, Dependency>
    let layout: Layout
    let elseContent: () -> ElseContent

    func body(content: Content) -> some View {
        ZStack {
            if let initialState {
                DismantleView(proxy: proxy, dependency: dependency, inject: { d in inject(d, initialState) })
                    .opacity(0)
                    .frame(width: 0, height: 0)
            }

            layout {
                if let store = proxy.store {
                    content
                        .environmentObject(store)
                } else {
                    elseContent()
                }
            }
        }
    }
}


// MARK: -
#if canImport(UIKit)
import UIKit

@MainActor
private protocol SystemViewRepresentable: UIViewRepresentable {
    typealias SystemView = UIView
    associatedtype ViewType: UIView

    func makeView(context: Context) -> ViewType
    func updateView(_ view: ViewType, context: Context)
    static func dismantleView(_ view: ViewType, coordinator: Coordinator)
}

extension SystemViewRepresentable {
    func makeUIView(context: Context) -> ViewType {
        makeView(context: context)
    }

    func updateUIView(_ uiView: ViewType, context: Context) {
        updateView(uiView, context: context)
    }

    static func dismantleUIView(_ uiView: ViewType, coordinator: Coordinator) {
        dismantleView(uiView, coordinator: coordinator)
    }
}

#elseif canImport(AppKit)
import AppKit

@MainActor
private protocol SystemViewRepresentable: NSViewRepresentable {
    typealias SystemView = NSView
    associatedtype ViewType: NSView

    func makeView(context: Context) -> ViewType
    func updateView(_ view: ViewType, context: Context)
    static func dismantleView(_ view: ViewType, coordinator: Coordinator)
}

extension SystemViewRepresentable {
    func makeNSView(context: Context) -> ViewType {
        makeView(context: context)
    }

    func updateNSView(_ nsView: ViewType, context: Context) {
        updateView(nsView, context: context)
    }

    static func dismantleNSView(_ nsView: ViewType, coordinator: Coordinator) {
        dismantleView(nsView, coordinator: coordinator)
    }
}

#else
#error("SystemViewRepresentable is not defined")
#endif

@MainActor
private struct DismantleView<State: Sendable, Action, Dependency>: SystemViewRepresentable {
    @ObservedObject var proxy: ProxyStore<State, Action, Dependency>
    let dependency: (EnvironmentValues) -> Dependency
    let inject: (Dependency) -> Store<State, Action, Dependency>

    class View: SystemView {
        var proxy: ProxyStore<State, Action, Dependency>?
    }

    func makeView(context: Context) -> View {
        let view = View()
        proxy.store = inject(dependency(context.environment))
        view.proxy = proxy
        return view
    }

    func updateView(_ view: View, context: Context) {
        proxy.store?.dependency = dependency(context.environment)
    }

    static func dismantleView(_ view: View, coordinator: ()) {
        view.proxy?.store = nil
    }
}

@preconcurrency import Combine

@MainActor
private class ProxyStore<State: Sendable, Action, Dependency>: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    var cancellable: AnyCancellable?

    var store: Store<State, Action, Dependency>? {
        willSet {
            defer {
                DispatchQueue.main.async { [self] in
                    objectWillChange.send()
                }
            }
            cancellable?.cancel()
            cancellable = nil
            if let newValue {
                cancellable = newValue.objectWillChange
                    .subscribe(objectWillChange)
            }
        }
    }
}
