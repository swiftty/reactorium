import SwiftUI

extension Effect.Send {
    public func callAsFunction(_ action: Action, animation: Animation?) {
        guard !Task.isCancelled else { return }
        withAnimation(animation) {
            body(action)
        }
    }
}
