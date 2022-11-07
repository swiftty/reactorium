import SwiftUI

extension Store {
    @propertyWrapper
    public struct Bindable {
        public struct Binder<V> {
            let store: Store
            let keyPath: KeyPath<State, V>

            @MainActor
            public func callAsFunction(action setter: @escaping (V) -> Action) -> Binding<V> {
                store.binding(get: { $0[keyPath: keyPath] }, set: setter)
            }

            @MainActor
            public func callAsFunction(action: @escaping @autoclosure () -> Action) -> Binding<V> {
                store.binding(get: { $0[keyPath: keyPath] }, set: { _ in action()})
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
                Binder(store: store, keyPath: keyPath)
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
