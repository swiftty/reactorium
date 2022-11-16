import SwiftUI

// MARK: -
extension View {
    @MainActor
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action, Dependency
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency
    ) -> some View {
        modifier(ProxyModifier(key: key, dependency: dependency) { dependency in
            Store(binding: binder, action: action, reducer: reducer, dependency: dependency)
        })
    }

    @MainActor
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>
    ) -> some View {
        scope(key: key, binding: binder, action: action, reducer: reducer, dependency: { _ in })
    }

    // MARK: with equatable
    @MainActor
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Sendable & Equatable, Action, Dependency
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency
    ) -> some View {
        modifier(ProxyModifier(key: key, dependency: dependency) { dependency in
            Store(binding: binder, action: action, reducer: reducer, dependency: dependency, removeDuplicates: ==)
        })
    }

    @MainActor
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Sendable & Equatable, Action
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>
    ) -> some View {
        scope(key: key, binding: binder, action: action, reducer: reducer, dependency: { _ in })
    }
}

// MARK: - for optional
extension View {
    @MainActor
    @ViewBuilder
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action, Dependency,
        ElseContent: View
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder else elseContent: () -> ElseContent = { EmptyView() }
    ) -> some View {
        if let value = binder.value {
            scope(key: key, binding: binder.map { $0 ?? value }, action: action, reducer: reducer, dependency: dependency)
        } else {
            elseContent()
        }
    }

    @MainActor
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action,
        ElseContent: View
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder else elseContent: () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: key, binding: binder, action: action, reducer: reducer, dependency: { _ in }, else: elseContent)
    }

    // MARK: with equatable
    @MainActor
    @ViewBuilder
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Sendable & Equatable, Action, Dependency,
        ElseContent: View
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder else elseContent: () -> ElseContent = { EmptyView() }
    ) -> some View {
        if let value = binder.value {
            scope(key: key, binding: binder.map { $0 ?? value }, action: action, reducer: reducer, dependency: dependency)
        } else {
            elseContent()
        }
    }

    @MainActor
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Sendable & Equatable, Action,
        ElseContent: View
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder else elseContent: () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: key, binding: binder, action: action, reducer: reducer, dependency: { _ in }, else: elseContent)
    }
}

// MARK: - for optional with custom layout
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Layout {
    @MainActor
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action, Dependency,
        ThenContent: View,
        ElseContent: View
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder then thenContent: @escaping () -> ThenContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() }
    ) -> some View {
        OptionalScoped(
            key: key,
            binding: binder,
            action: action,
            reducer: reducer,
            dependency: dependency,
            in: self,
            then: thenContent,
            else: elseContent,
            removeDuplicates: nil
        )
    }

    @MainActor
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Sendable, Action,
        ThenContent: View,
        ElseContent: View
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder then thenContent: @escaping () -> ThenContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: key, binding: binder, action: action, reducer: reducer, dependency: { _ in }, then: thenContent, else: elseContent)
    }

    // MARK: with equatable
    @MainActor
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Equatable & Sendable, Action, Dependency,
        ThenContent: View,
        ElseContent: View
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: @escaping (EnvironmentValues) -> Dependency,
        @ViewBuilder then thenContent: @escaping () -> ThenContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() }
    ) -> some View {
        OptionalScoped(
            key: key,
            binding: binder,
            action: action,
            reducer: reducer,
            dependency: dependency,
            in: self,
            then: thenContent,
            else: elseContent
        )
    }

    @MainActor
    public func scope<
        Key: Equatable,
        PState: Sendable, PAction, PDependency,
        State: Equatable & Sendable, Action,
        ThenContent: View,
        ElseContent: View
    >(
        key: Key? = 0,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<State?>,
        action: @escaping (State) -> PAction,
        reducer: some Reducer<State, Action, Void>,
        @ViewBuilder then thenContent: @escaping () -> ThenContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() }
    ) -> some View {
        scope(key: key, binding: binder, action: action, reducer: reducer, dependency: { _ in }, then: thenContent, else: elseContent)
    }
}

// MARK: -
private struct ProxyModifier<Key: Equatable, State: Sendable, Action, Dependency>: ViewModifier {
    @StateObject var proxy = ProxyStore<State, Action, Dependency>()
    let key: Key?
    let dependency: (EnvironmentValues) -> Dependency
    let inject: (Dependency) -> Store<State, Action, Dependency>

    func body(content: Content) -> some View {
        ZStack {
            DismantleView(proxy: proxy, key: key, dependency: dependency, inject: inject)
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
private struct OptionalScoped<
    Key: Equatable,
    PState: Sendable, PAction, PDependency,
    R: Reducer,
    Layout: SwiftUI.Layout,
    ThenContent: View,
    ElseContent: View
>: View where R.State: Sendable {
    let key: Key?
    let binder: Store<PState, PAction, PDependency>.Bindable.Binder<R.State?>
    let action: (R.State) -> PAction
    let reducer: R
    let dependency: (EnvironmentValues) -> R.Dependency
    let layout: Layout
    let thenContent: () -> ThenContent
    let elseContent: () -> ElseContent
    let isDuplicates: ((R.State, R.State) -> Bool)?

    @StateObject var proxy = ProxyStore<R.State, R.Action, R.Dependency>()

    init(
        key: Key?,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<R.State?>,
        action: @escaping (R.State) -> PAction,
        reducer: R,
        dependency: @escaping (EnvironmentValues) -> R.Dependency,
        in layout: Layout,
        @ViewBuilder then thenContent: @escaping () -> ThenContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() },
        removeDuplicates isDuplicates: ((R.State, R.State) -> Bool)?
    ) {
        self.key = key
        self.binder = binder
        self.action = action
        self.reducer = reducer
        self.dependency = dependency
        self.layout = layout
        self.thenContent = thenContent
        self.elseContent = elseContent
        self.isDuplicates = isDuplicates
    }

    init(
        key: Key?,
        binding binder: Store<PState, PAction, PDependency>.Bindable.Binder<R.State?>,
        action: @escaping (R.State) -> PAction,
        reducer: R,
        dependency: @escaping (EnvironmentValues) -> R.Dependency,
        in layout: Layout,
        @ViewBuilder then thenContent: @escaping () -> ThenContent,
        @ViewBuilder else elseContent: @escaping () -> ElseContent = { EmptyView() }
    ) where R.State: Equatable {
        self.init(key: key, binding: binder, action: action, reducer: reducer, dependency: dependency,
                  in: layout, then: thenContent, else: elseContent, removeDuplicates: ==)
    }

    var body: some View {
        ZStack {
            if let state = binder.value {
                DismantleView(proxy: proxy, key: key, dependency: dependency, inject: { dependency in
                    Store(
                        binding: binder.map { $0 ?? state },
                        action: action,
                        reducer: reducer,
                        dependency: dependency,
                        removeDuplicates: isDuplicates
                    )
                })
                .opacity(0)
                .frame(width: 0, height: 0)
            }

            layout {
                if let store = proxy.store {
                    thenContent()
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
private struct DismantleView<Key: Equatable, State: Sendable, Action, Dependency>: SystemViewRepresentable {
    @ObservedObject var proxy: ProxyStore<State, Action, Dependency>
    let key: Key?
    let dependency: (EnvironmentValues) -> Dependency
    let inject: (Dependency) -> Store<State, Action, Dependency>

    class View: SystemView {
        var proxy: ProxyStore<State, Action, Dependency>?
        var key: Key?
    }

    func makeView(context: Context) -> View {
        let view = View()
        proxy.store = inject(dependency(context.environment))
        view.proxy = proxy
        view.key = key
        return view
    }

    func updateView(_ view: View, context: Context) {
        let dependency = dependency(context.environment)
        if view.key != key {
            view.key = key
            proxy.store = inject(dependency)
        }
        proxy.store?.dependency = dependency
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
