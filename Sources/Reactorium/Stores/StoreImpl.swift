import SwiftUI
import Combine

@usableFromInline
@MainActor
protocol StoreImpl<State, Action, Dependency>: ObservableObject, Sendable {
    associatedtype State: Sendable
    associatedtype Action
    associatedtype Dependency

    var state: State { get }
    var reducer: any Reducer<State, Action, Dependency> { get }
    var dependency: Dependency { get set }

    var objectWillChange: ObservableObjectPublisher { get }

    func _send(_ newAction: Action) -> Task<Void, Never>?

    func yield(while predicate: @escaping @Sendable (State) -> Bool) async

    func binding<V>(get getter: @escaping (State) -> V, set setter: @escaping (V) -> Action) -> Binding<V>
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
