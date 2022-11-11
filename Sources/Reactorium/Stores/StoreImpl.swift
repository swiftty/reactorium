import SwiftUI
import Combine

@usableFromInline
@MainActor
protocol StoreImpl<State, Action, Dependency>: ObservableObject, Sendable {
    associatedtype State: Sendable
    associatedtype Action
    associatedtype Dependency

    var state: State { get set }
    var reducer: any Reducer<State, Action, Dependency> { get }
    var dependency: Dependency { get set }

    var objectWillChange: ObservableObjectPublisher { get }

    var bufferdActions: [Action] { get set }
    var isSending: Bool { get set }
    var runningTasks: Set<Task<Void, Never>> { get set }

    func yield(while predicate: @escaping @Sendable (State) -> Bool) async
}

extension StoreImpl {
    @usableFromInline
    @discardableResult
    func send(_ newAction: Action) -> Store<State, Action, Dependency>.ActionTask {
        let task = _send(newAction)
        return .init(task: task)
    }

    @usableFromInline
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
}

extension StoreImpl {
    @usableFromInline
    func _send(_ newAction: Action) -> Task<Void, Never>? {
        bufferdActions.append(newAction)
        guard !isSending else { return nil }

        isSending = true
        var currentState = state

        var tasks: [Task<Void, Never>] = []
        defer {
            bufferdActions.removeAll()
            state = currentState
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
                    await runner(Effect.Send { action in
                        let task = self?._send(action)
                        assert(task == nil)
                    })
                })
            }
        }

        guard !tasks.isEmpty else { return nil }

        let task =  Task.detached {
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
        runningTasks.insert(task)
        Task { [weak self] in
            await task.value
            self?.runningTasks.remove(task)
        }
        return task
    }
}
