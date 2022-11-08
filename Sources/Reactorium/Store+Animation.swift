import SwiftUI

extension Store {
    @inlinable
    @discardableResult
    public func send(_ newAction: Action, animation: Animation?) -> ActionTask {
        withAnimation(animation) {
            send(newAction)
        }
    }

    @inlinable
    public func send(_ newAction: Action, animation: Animation?, while predicate: @escaping @Sendable (State) -> Bool) async {
        let task = send(newAction, animation: animation)
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
