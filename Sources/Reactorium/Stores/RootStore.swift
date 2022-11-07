import SwiftUI
@preconcurrency import Combine

@MainActor
protocol StoreImpl<State, Action, Dependency> {
    associatedtype State: Sendable
    associatedtype Action
    associatedtype Dependency

    var state: State { get }
    var dependency: Dependency { get set }

    var objectWillChange: ObservableObjectPublisher { get }

    func send(_ newAction: Action) -> Store<State, Action, Dependency>.ActionTask
    func send(_ newAction: Action, while predicate: @escaping @Sendable (State) -> Bool) async

    func yield(while predicate: @escaping @Sendable (State) -> Bool) async
}

@MainActor
class RootStore<State: Sendable, Action, Dependency>: StoreImpl {
    var state: State { _state.value }
    let reducer: any Reducer<State, Action, Dependency>
    var dependency: Dependency
    let objectWillChange = ObservableObjectPublisher()

    let _state: CurrentValueSubject<State, Never>

    @usableFromInline
    private(set) var cancellables: AnyCancellable? = nil

    @usableFromInline
    var bufferdActions: [Action] = []

    @usableFromInline
    var isSending = false

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

        if let isDuplicate {
            cancellables = _state
                .dropFirst()
                .removeDuplicates(by: isDuplicate)
                .sink { [weak self] _ in
                    assert(Thread.isMainThread)
                    self?.objectWillChange.send()
                }
        } else {
            cancellables = _state
                .dropFirst()
                .sink { [weak self] _ in
                    assert(Thread.isMainThread)
                    self?.objectWillChange.send()
                }
        }
    }


    // MARK: -
    @inlinable
    func send(_ newAction: Action) -> Store<State, Action, Dependency>.ActionTask {
        let task = _send(newAction, from: nil)
        return .init(task: task)
    }

    @inlinable
    func send(_ newAction: Action, while predicate: @escaping @Sendable (State) -> Bool) async {
        let task = send(newAction)
        await Task.detached { [weak self] in
            await withTaskCancellationHandler {
                await self?.yield(while: predicate)
            } onCancel: {
                Task {
                    await task.cancel()
                }
            }
        }.value
    }

    @usableFromInline
    func _send(_ newAction: Action, from originalAction: Action?) -> Task<Void, Never>? {
        bufferdActions.append(newAction)
        guard !isSending else { return nil }

        isSending = true
        var currentState = _state.value

        var tasks: [Task<Void, Never>] = []
        defer {
            bufferdActions.removeAll()
            _state.value = currentState
            isSending = false
            assert(bufferdActions.isEmpty)
        }

        let dependency = dependency
        var index = bufferdActions.startIndex
        while index < bufferdActions.endIndex {
            defer { index += 1 }

            let newAction = bufferdActions[index]
            let effect = reducer.reduce(into: &currentState, action: newAction, dependency: dependency)

            switch effect.operation {
            case .none:
                break

            case .task(let priority, let runner):
                tasks.append(Task(priority: priority) { [weak self] in
                    await runner(Effect.Send {
                        if let task = self?._send($0, from: newAction) {
                            tasks.append(task)
                        }
                    })
                })
            }
        }

        guard !tasks.isEmpty else { return nil }

        return Task.detached {
            await withTaskCancellationHandler { @MainActor in
                var i = tasks.startIndex
                while i < tasks.endIndex {
                    defer { i += 1 }
                    await tasks[i].value
                }
            } onCancel: {
                Task { @MainActor in
                    var i = tasks.startIndex
                    while i < tasks.endIndex {
                        defer { i += 1 }
                        tasks[i].cancel()
                    }
                }
            }
        }
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
}