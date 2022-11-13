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
        if #available(macOS 12, iOS 15, tvOS 15, *) {
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
