import Foundation
import CustomDump

extension Reducer where State: Sendable, Action: Sendable {
    @inlinable
    public func _printChanges(
        _ printer: _ReducePrinter<State, Action>? = .customDump
    ) -> some Reducer<State, Action, Dependency> {
        _PrintChanges(base: self, printer: printer)
    }
}

// MARK: -
public struct _ReducePrinter<State, Action>: @unchecked Sendable {
    private let _printChange: (Action, State, State) -> Void

    init(printChange: @escaping (Action, State, State) -> Void) {
        _printChange = printChange
    }

    public func printChange(receivedAction: Action, oldState: State, newState: State) {
        _printChange(receivedAction, oldState, newState)
    }
}

extension _ReducePrinter {
    public static var customDump: Self {
        self.init { receivedAction, oldState, newState in
            var target = ""
            target.write("received action:\n")
            CustomDump.customDump(receivedAction, to: &target, indent: 2)
            target.write("\n")
            target.write(diff(oldState, newState).map { "\($0)\n" } ?? "  (No state changes)\n")
            print(target)
        }
    }
}

// MARK: -
@usableFromInline
struct _PrintChanges<Base: Reducer>: Reducer where Base.State: Sendable, Base.Action: Sendable {
    @usableFromInline typealias State = Base.State
    @usableFromInline typealias Action = Base.Action
    @usableFromInline typealias Dependency = Base.Dependency

    @usableFromInline
    let base: Base

    @usableFromInline
    let printer: _ReducePrinter<State, Action>?

    @usableFromInline
    init(base: Base, printer: _ReducePrinter<State, Action>?) {
        self.base = base
        self.printer = printer
    }

    @usableFromInline
    func reduce(into state: inout State, action: Action, dependency: Dependency) -> Effect<Action> {
        #if DEBUG
        if let printer {
            let oldState = state
            let effects = base.reduce(into: &state, action: action, dependency: dependency)
            return effects.merge(with: .task { [newState = state] _ in
                printer.printChange(receivedAction: action, oldState: oldState, newState: newState)
            })
        }
        #endif
        return base.reduce(into: &state, action: action, dependency: dependency)
    }
}
