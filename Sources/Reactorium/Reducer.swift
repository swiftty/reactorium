import Foundation

public protocol Reducer<State, Action, Dependency> {
    associatedtype State
    associatedtype Action
    associatedtype Dependency = Void

    func reduce(into state: inout State, action: Action, dependency: Dependency) -> Effect<Action>
}
