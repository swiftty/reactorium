import SwiftUI

extension Store {
    @propertyWrapper
    public struct Bindable {
        public struct Binder<V> {
            let store: Store
            let getter: (State) -> V

            @MainActor
            public func callAsFunction(action setter: @escaping (V) -> Action) -> Binding<V> {
                store.binding(get: getter, set: setter)
            }

            @MainActor
            public func callAsFunction(action: @escaping @autoclosure () -> Action) -> Binding<V> {
                store.binding(get: getter, set: { _ in action()})
            }

            @MainActor
            var value: V { getter(store.state) }

            @MainActor
            func map<T>(_ transform: @escaping (V) -> T) -> Binder<T> {
                Binder<T>(store: store, getter: { transform(getter($0)) })
            }
        }

        public init() {}

        // MARK: - wrappedValue
        @available(*, unavailable, message: "@StateBinder can only be applied to store")
        public var wrappedValue: State {
            get { fatalError() }
        }

        @MainActor
        public static subscript(
            _enclosingInstance instance: Store,
            wrapped wrappedKeyPath: KeyPath<Store, State>,
            storage storageKeyPath: KeyPath<Store, Self>
        ) -> State {
            instance.impl.state
        }

        // MARK: - projectedValue
        @dynamicMemberLookup
        public struct Wrapper {
            let store: Store

            public subscript <V> (dynamicMember keyPath: KeyPath<State, V>) -> Binder<V> {
                Binder(store: store, getter: { $0[keyPath: keyPath] })
            }
        }

        @available(*, unavailable, message: "@StateBinder can only be applied to store")
        public var projectedValue: Wrapper {
            get { fatalError() }
        }

        @MainActor
        public static subscript(
            _enclosingInstance instance: Store,
            projected projectedKeyPath: KeyPath<Store, Wrapper>,
            storage storageKeyPath: KeyPath<Store, Self>
        ) -> Wrapper {
            Wrapper(store: instance)
        }
    }
}
