import SwiftUI

extension Effect {
    @MainActor
    public struct Send {
        let body: @MainActor (Action) -> Void

        @usableFromInline
        init(body: @escaping (Action) -> Void) {
            self.body = body
        }

        public func callAsFunction(_ action: Action) {
            guard !Task.isCancelled else { return }
            body(action)
        }

        public func callAsFunction(_ action: Action, animation: Animation?) {
            guard !Task.isCancelled else { return }
            withAnimation(animation) {
                body(action)
            }
        }
    }
}
