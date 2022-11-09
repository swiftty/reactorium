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
