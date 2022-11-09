import SwiftUI
@preconcurrency import Combine

@MainActor
class RootStore<State: Sendable, Action, Dependency>: StoreImpl {
    var state: State {
        get { _state.value }
        set {
            let fire: Bool = {
                guard let isDuplicate else { return true }
                return !isDuplicate(_state.value, newValue)
            }()
            if fire {
                objectWillChange.send()
            }
            _state.value = newValue
        }
    }
    let reducer: any Reducer<State, Action, Dependency>
    var dependency: Dependency
    let objectWillChange = ObservableObjectPublisher()

    var bufferdActions: [Action] = []
    var isSending = false
    var runningTasks: Set<Task<Void, Never>> = []

    private let _state: CurrentValueSubject<State, Never>
    private let isDuplicate: ((State, State) -> Bool)?

    // MARK: -
    init(
        initialState: State,
        reducer: some Reducer<State, Action, Dependency>,
        dependency: Dependency,
        removeDuplicates isDuplicate: ((State, State) -> Bool)? = nil
    ) {
        _state = .init(initialState)
        self.reducer = reducer
        self.dependency = dependency
        self.isDuplicate = isDuplicate
    }

    deinit {
        runningTasks.forEach { $0.cancel() }
    }

    // MARK: -
    @usableFromInline
    func yield(while predicate: @escaping @Sendable (State) -> Bool) async {
        if #available(iOS 15, macOS 12, *) {
            for await state in _state.values where !predicate(state) {
                return
            }
        } else {
            let state = _state
            let context = YieldContext()
            Task.detached {
                try? await withTaskCancellationHandler {
                    try Task.checkCancellation()
                    _ = try await context.register(state.filter { !predicate($0) })
                } onCancel: {
                    Task {
                        await context.cancel()
                    }
                }
            }
        }
    }

    func binding<V>(get getter: @escaping (State) -> V, set setter: @escaping (V) -> Action) -> Binding<V> {
        ObservedObject(wrappedValue: self)
            .projectedValue[get: .init(value: getter), set: .init(value: setter)]
    }

    private subscript <V> (get getter: HashableWrapper<(State) -> V>, set setter: HashableWrapper<(V) -> Action>) -> V {
        get { getter.value(state) }
        set { send(setter.value(newValue)) }
    }
}

// MARK: -
actor YieldContext {
    private var cancellable: AnyCancellable?

    func register<T>(_ values: some Publisher<T, Never>) async throws -> T {
        cancel()
        return try await withUnsafeThrowingContinuation { continuation in
            if Task.isCancelled {
                continuation.resume(throwing: CancellationError())
            }
            cancellable = values
                .prefix(1)
                .sink { value in
                    continuation.resume(returning: value)
                }
        }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}

private struct HashableWrapper<V>: Hashable, @unchecked Sendable {
    let value: V

    static func == (lhs: Self, rhs: Self) -> Bool { true }
    func hash(into hasher: inout Hasher) {}
}
